#!/usr/bin/env bash

set -euo pipefail

TEST_SCOPE="${1:-all}"
WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IRIS_CONTAINER_NAME="${IRIS_CONTAINER_NAME:-iris111}"

run_iris_session() {
	local script_file="$1"
	local output
	output="$(docker exec -i "$IRIS_CONTAINER_NAME" bash -lc '/home/irisowner/bin/iris session IRIS' < "$script_file")"
	printf '%s\n' "$output"
	if printf '%s\n' "$output" | grep -q '^FAIL:'; then
		return 1
	fi
}

make_script_file() {
	mktemp "${TMPDIR:-/tmp}/iris111-tests.XXXXXX"
}

run_budget_test() {
	local script_file
	script_file="$(make_script_file)"
	cat > "$script_file" <<'EOF'
set budgetDate = $ZDATEH("2026-05-13", 3)
set storeCode = "GT-0145"
set budgetCsv = "budget_date,store_code,category_code,target_units,target_revenue"_$c(10)_("2026-05-13,GT-0145,BEBIDAS,50,175000")_$c(10)_("2026-05-13,GT-0145,ACEITES,25,222500")
kill ^IRIS111("budget", budgetDate, storeCode)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare budget cleanup",! halt }
do stmt.%Execute(budgetDate, storeCode)

set status = ##class(Service.BudgetImportService).ImportCsv(budgetCsv)
if $SYSTEM.Status.IsError(status) { write !,"FAIL: budget import failed",! halt }

set units = ##class(Process.POSProcessingBPL).GetBudgetUnits(budgetDate, storeCode, "BEBIDAS")
set revenue = ##class(Process.POSProcessingBPL).GetBudgetRevenue(budgetDate, storeCode, "ACEITES")
if units '= 50 { write !,"FAIL: expected 50 budget units",! halt }
if revenue '= 222500 { write !,"FAIL: expected 222500 budget revenue",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt FROM MD.SalesBudget WHERE BudgetDate = ? AND StoreCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare budget count",! halt }
set rs = stmt.%Execute(budgetDate, storeCode)
if 'rs.%Next() { write !,"FAIL: missing budget count row",! halt }
if +rs.%GetData(1) '= 2 { write !,"FAIL: expected 2 budget rows",! halt }

write !,"budget smoke passed",!
halt
EOF
	run_iris_session "$script_file"
	local status=$?
	rm -f "$script_file"
	return "$status"
}

run_pos_test() {
	local script_file
	script_file="$(make_script_file)"
	cat > "$script_file" <<'EOF'
set budgetDate = $ZDATEH("2026-05-13", 3)
set saleHour = 8
set storeCode = "GT-0145"
set categoryCode = "BEBIDAS"
set bronzeSourceId = "pos-evt-001"
set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, saleHour)
set bronzePattern = "%pos-evt-001%"

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Bronze.POSEvent WHERE Payload LIKE ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare bronze cleanup",! halt }
do stmt.%Execute(bronzePattern)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Silver.Sale WHERE StoreCode = ? AND CategoryCode = ? AND Qty = ? AND Price = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare silver cleanup",! halt }
do stmt.%Execute(storeCode, categoryCode, 2, 3500)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Gold.CategoryPace WHERE PaceId = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare gold cleanup",! halt }
do stmt.%Execute(paceId)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare recommendation cleanup",! halt }
do stmt.%Execute(storeCode, categoryCode)

set json = "{""source_id"":""pos-evt-001"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T08:10:00Z"",""category_code"":""BEBIDAS"",""internal_sku"":""SKU-1001"",""qty"":2,""price"":3500}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: POS handling failed",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt FROM Bronze.POSEvent WHERE Payload LIKE ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare bronze count",! halt }
set rs = stmt.%Execute(bronzePattern)
if 'rs.%Next() { write !,"FAIL: missing bronze count row",! halt }
if +rs.%GetData(1) '= 1 { write !,"FAIL: expected 1 bronze row",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt FROM Silver.Sale WHERE StoreCode = ? AND CategoryCode = ? AND Qty = ? AND Price = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare silver count",! halt }
set rs = stmt.%Execute(storeCode, categoryCode, 2, 3500)
if 'rs.%Next() { write !,"FAIL: missing silver count row",! halt }
if +rs.%GetData(1) '= 1 { write !,"FAIL: expected 1 silver row",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt FROM Gold.CategoryPace WHERE PaceId = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare gold count",! halt }
set rs = stmt.%Execute(paceId)
if 'rs.%Next() { write !,"FAIL: missing gold count row",! halt }
if +rs.%GetData(1) '= 1 { write !,"FAIL: expected 1 gold row",! halt }

write !,"pos smoke passed",!
halt
EOF
	run_iris_session "$script_file"
	local status=$?
	rm -f "$script_file"
	return "$status"
}

run_gold_test() {
	local script_file
	script_file="$(make_script_file)"
	cat > "$script_file" <<'EOF'
set budgetDate = $ZDATEH("2026-05-13", 3)
set saleHour = 8
set storeCode = "GT-0145"
set categoryCode = "BEBIDAS"
set bronzeSourceId = "pos-evt-001"
set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, saleHour)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT UnitsBudget, RevenueBudget, UnitsSold, RevenueSold, VarianceUnits, VarianceRevenue FROM Gold.CategoryPace WHERE PaceId = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare gold validation",! halt }
set rs = stmt.%Execute(paceId)
if 'rs.%Next() { write !,"FAIL: missing gold validation row",! halt }

if +rs.%GetData(1) '= 50 { write !,"FAIL: expected 50 budget units in gold",! halt }
if +rs.%GetData(2) '= 175000 { write !,"FAIL: expected 175000 budget revenue in gold",! halt }
if +rs.%GetData(3) '= 2 { write !,"FAIL: expected 2 sold units in gold",! halt }
if +rs.%GetData(4) '= 7000 { write !,"FAIL: expected 7000 sold revenue in gold",! halt }
if +rs.%GetData(5) '= -48 { write !,"FAIL: expected -48 unit variance in gold",! halt }
if +rs.%GetData(6) '= -168000 { write !,"FAIL: expected -168000 revenue variance in gold",! halt }

write !,"gold smoke passed",!
halt
EOF
	run_iris_session "$script_file"
	local status=$?
	rm -f "$script_file"
	return "$status"
}

run_rules_test() {
	local script_file
	script_file="$(make_script_file)"
	cat > "$script_file" <<'EOF'
set budgetDate = $ZDATEH("2026-05-13", 3)
set storeCode = "GT-0145"
set categoryCode = "BEBIDAS"
set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, 10)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Gold.CategoryPace WHERE PaceDate = ? AND StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare gold cleanup",! halt }
do stmt.%Execute(budgetDate, storeCode, categoryCode)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare recommendation cleanup",! halt }
do stmt.%Execute(storeCode, categoryCode)

set budgetCsv = "budget_date,store_code,category_code,target_units,target_revenue"_$c(10)_("2026-05-13,GT-0145,BEBIDAS,50,175000")
set status = ##class(Service.BudgetImportService).ImportCsv(budgetCsv)
if $SYSTEM.Status.IsError(status) { write !,"FAIL: budget import failed for sustained rules",! halt }

set json = "{""source_id"":""pos-evt-rule-001"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T08:10:00Z"",""category_code"":""BEBIDAS"",""internal_sku"":""SKU-1001"",""qty"":40,""price"":3500}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: first sustained POS handling failed",! halt }

set json = "{""source_id"":""pos-evt-rule-002"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T09:10:00Z"",""category_code"":""BEBIDAS"",""internal_sku"":""SKU-1001"",""qty"":40,""price"":3500}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: second sustained POS handling failed",! halt }

set json = "{""source_id"":""pos-evt-rule-003"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T10:10:00Z"",""category_code"":""BEBIDAS"",""internal_sku"":""SKU-1001"",""qty"":40,""price"":3500}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: third sustained POS handling failed",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt, MAX(RuleFired) AS RuleFired, MAX(RuleWindowType) AS RuleWindowType, MAX(RulePriority) AS RulePriority, MAX(RuleThreshold) AS RuleThreshold, MAX(RuleObservedValue) AS RuleObservedValue FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare recommendation validation",! halt }
set rs = stmt.%Execute(storeCode, categoryCode)
if 'rs.%Next() { write !,"FAIL: missing recommendation validation row",! halt }

if +rs.%GetData(1) < 1 { write !,"FAIL: expected at least 1 recommendation",! halt }
if rs.%GetData(2) '= "PACE_NEGATIVE_SUSTAINED" { write !,"FAIL: expected sustained rule fired",! halt }
if rs.%GetData(3) '= "HOURLY_STREAK" { write !,"FAIL: expected sustained window type",! halt }
if +rs.%GetData(4) '= 2 { write !,"FAIL: expected sustained priority 2",! halt }
if +rs.%GetData(5) '= 3 { write !,"FAIL: expected sustained threshold 3",! halt }
if +rs.%GetData(6) '= 3 { write !,"FAIL: expected sustained observed count 3",! halt }

set storeCode = "GT-0145"
set categoryCode = "ACEITES"
set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, 11)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Gold.CategoryPace WHERE PaceDate = ? AND StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare stockout gold cleanup",! halt }
do stmt.%Execute(budgetDate, storeCode, categoryCode)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare stockout recommendation cleanup",! halt }
do stmt.%Execute(storeCode, categoryCode)

set budgetCsv = "budget_date,store_code,category_code,target_units,target_revenue"_$c(10)_("2026-05-13,GT-0145,ACEITES,0,0")
set status = ##class(Service.BudgetImportService).ImportCsv(budgetCsv)
if $SYSTEM.Status.IsError(status) { write !,"FAIL: stockout budget import failed",! halt }

set json = "{""source_id"":""pos-evt-stock-001"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T11:10:00Z"",""category_code"":""ACEITES"",""internal_sku"":""SKU-2001"",""qty"":0,""price"":0}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: first stockout POS handling failed",! halt }

set json = "{""source_id"":""pos-evt-stock-002"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T12:10:00Z"",""category_code"":""ACEITES"",""internal_sku"":""SKU-2001"",""qty"":0,""price"":0}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: second stockout POS handling failed",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt, MAX(RuleFired) AS RuleFired, MAX(RuleWindowType) AS RuleWindowType, MAX(RulePriority) AS RulePriority, MAX(RuleThreshold) AS RuleThreshold, MAX(RuleObservedValue) AS RuleObservedValue FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare stockout validation",! halt }
set rs = stmt.%Execute(storeCode, categoryCode)
if 'rs.%Next() { write !,"FAIL: missing stockout validation row",! halt }

if +rs.%GetData(1) < 1 { write !,"FAIL: expected at least 1 stockout recommendation",! halt }
if rs.%GetData(2) '= "STOCKOUT_INFERRED" { write !,"FAIL: expected stockout rule fired",! halt }
if rs.%GetData(3) '= "NO_SALES" { write !,"FAIL: expected stockout window type",! halt }
if +rs.%GetData(4) '= 3 { write !,"FAIL: expected stockout priority 3",! halt }
if +rs.%GetData(5) '= 2 { write !,"FAIL: expected stockout threshold 2",! halt }
if +rs.%GetData(6) '= 2 { write !,"FAIL: expected stockout observed count 2",! halt }

write !,"rules smoke passed",!
halt
EOF
	run_iris_session "$script_file"
	local status=$?
	rm -f "$script_file"
	return "$status"
}

run_api_test() {
	local script_file
	script_file="$(make_script_file)"
	cat > "$script_file" <<'EOF'
set budgetDate = $ZDATEH("2026-05-13", 3)
set storeCode = "GT-0145"
set categoryCode = "BEBIDAS"
set paceHour = 8
set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, paceHour)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Gold.CategoryPace WHERE PaceDate = ? AND StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare api gold cleanup",! halt }
do stmt.%Execute(budgetDate, storeCode, categoryCode)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare api recommendation cleanup",! halt }
do stmt.%Execute(storeCode, categoryCode)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Ops.AuditLog WHERE EntityName = ? AND EntityId = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare api audit cleanup",! halt }
do stmt.%Execute("Gold.CategoryPace", storeCode _ "|" _ categoryCode)

set budgetCsv = "budget_date,store_code,category_code,target_units,target_revenue"_$c(10)_("2026-05-13,GT-0145,BEBIDAS,50,175000")
set status = ##class(Service.BudgetImportService).ImportCsv(budgetCsv)
if $SYSTEM.Status.IsError(status) { write !,"FAIL: api budget import failed",! halt }

set json = "{""source_id"":""pos-evt-api-001"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T08:10:00Z"",""category_code"":""BEBIDAS"",""internal_sku"":""SKU-1001"",""qty"":2,""price"":3500}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: api POS handling failed",! halt }

set health = ##class(API.UIController).BuildHealthData()
if health.status '= "ok" { write !,"FAIL: health status not ok",! halt }

set pace = ##class(API.UIController).BuildPaceData(storeCode, categoryCode, budgetDate, paceHour)
if pace.paceId = "" { write !,"FAIL: pace data not found",! halt }
if +pace.unitsSold '= 2 { write !,"FAIL: pace units mismatch",! halt }
set status = ##class(API.UIController).AuditRequest("Gold.CategoryPace", storeCode _ "|" _ categoryCode, "READ_PACE", "", pace.%ToJSON())
if $SYSTEM.Status.IsError(status) { write !,"FAIL: api audit save failed",! halt }

set pending = ##class(API.UIController).BuildPendingRecommendationsData(storeCode)
if pending.%Size() < 1 { write !,"FAIL: expected pending recommendations",! halt }
set recommendationId = pending.%Get(0).RecommendationId

set feedback = ##class(API.UIController).ApplyFeedback(recommendationId, "ACCEPTED", "store.manager", "accepted from api test")
if feedback.saved '= 1 { write !,"FAIL: feedback save failed",! halt }
if feedback.after.Status '= "ACCEPTED" { write !,"FAIL: feedback status mismatch",! halt }

set dashboard = ##class(API.UIController).BuildDashboardData(storeCode)
if dashboard.categories.%Size() < 1 { write !,"FAIL: dashboard categories missing",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt FROM Ops.AuditLog WHERE EntityName = ? AND EntityId = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare audit count",! halt }
set rs = stmt.%Execute("Gold.CategoryPace", storeCode _ "|" _ categoryCode)
if 'rs.%Next() { write !,"FAIL: missing audit row",! halt }
if +rs.%GetData(1) < 1 { write !,"FAIL: expected audit record",! halt }

write !,"api smoke passed",!
halt
EOF
	run_iris_session "$script_file"
	local status=$?
	rm -f "$script_file"
	return "$status"
}

run_priority_test() {
	local script_file
	script_file="$(make_script_file)"
	cat > "$script_file" <<'EOF'
set budgetDate = $ZDATEH("2026-05-13", 3)
set storeCode = "GT-0145"
set categoryCode = "BEBIDAS"
set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, 10)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Gold.CategoryPace WHERE PaceDate = ? AND StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare priority gold cleanup",! halt }
do stmt.%Execute(budgetDate, storeCode, categoryCode)

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("DELETE FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare priority recommendation cleanup",! halt }
do stmt.%Execute(storeCode, categoryCode)

set budgetCsv = "budget_date,store_code,category_code,target_units,target_revenue"_$c(10)_("2026-05-13,GT-0145,BEBIDAS,10,35000")
set status = ##class(Service.BudgetImportService).ImportCsv(budgetCsv)
if $SYSTEM.Status.IsError(status) { write !,"FAIL: budget import failed for priority test",! halt }

set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, 8)
set pace = ##class(Gold.CategoryPace).%New()
set pace.PaceId = paceId
set pace.PaceDate = budgetDate
set pace.PaceHour = 8
set pace.StoreCode = storeCode
set pace.CategoryCode = categoryCode
set pace.UnitsSold = 0
set pace.RevenueSold = 0
set pace.UnitsBudget = 10
set pace.RevenueBudget = 35000
set pace.UnitsCumulative = 0
set pace.RevenueCumulative = 0
set pace.PctPaceUnits = 0
set pace.PctPaceRevenue = 0
set pace.VarianceUnits = -10
set pace.VarianceRevenue = -35000
set pace.LastUpdated = $ZDATETIME($HOROLOG, 3, 1)
set status = pace.%Save()
if $SYSTEM.Status.IsError(status) { write !,"FAIL: first seeded gold row failed",! halt }

set paceId = ##class(Process.POSProcessingBPL).BuildPaceId(storeCode, categoryCode, budgetDate, 9)
set pace = ##class(Gold.CategoryPace).%New()
set pace.PaceId = paceId
set pace.PaceDate = budgetDate
set pace.PaceHour = 9
set pace.StoreCode = storeCode
set pace.CategoryCode = categoryCode
set pace.UnitsSold = 0
set pace.RevenueSold = 0
set pace.UnitsBudget = 10
set pace.RevenueBudget = 35000
set pace.UnitsCumulative = 0
set pace.RevenueCumulative = 0
set pace.PctPaceUnits = 0
set pace.PctPaceRevenue = 0
set pace.VarianceUnits = -10
set pace.VarianceRevenue = -35000
set pace.LastUpdated = $ZDATETIME($HOROLOG, 3, 1)
set status = pace.%Save()
if $SYSTEM.Status.IsError(status) { write !,"FAIL: second seeded gold row failed",! halt }

set json = "{""source_id"":""pos-evt-priority-003"",""store_code"":""GT-0145"",""timestamp"":""2026-05-13T10:10:00Z"",""category_code"":""BEBIDAS"",""internal_sku"":""SKU-1001"",""qty"":0,""price"":0}"
set status = ##class(Process.POSProcessingBPL).HandlePayload(json, "REST")
if $SYSTEM.Status.IsError(status) { write !,"FAIL: third priority POS handling failed",! halt }

set stmt = ##class(%SQL.Statement).%New()
set sc = stmt.%Prepare("SELECT COUNT(*) AS Cnt, MAX(RuleFired) AS RuleFired, MAX(RuleWindowType) AS RuleWindowType, MAX(RulePriority) AS RulePriority, MAX(RuleSeverity) AS RuleSeverity, MAX(BusinessMessage) AS BusinessMessage, MAX(ExecutionState) AS ExecutionState FROM Ops.Recommendation WHERE StoreCode = ? AND CategoryCode = ?")
if $SYSTEM.Status.IsError(sc) { write !,"FAIL: unable to prepare priority validation",! halt }
set rs = stmt.%Execute(storeCode, categoryCode)
if 'rs.%Next() { write !,"FAIL: missing priority validation row",! halt }

if +rs.%GetData(1) '= 1 { write !,"FAIL: expected exactly 1 priority recommendation",! halt }
if rs.%GetData(2) '= "PACE_NEGATIVE_SUSTAINED" { write !,"FAIL: expected sustained rule to win priority",! halt }
if rs.%GetData(3) '= "HOURLY_STREAK" { write !,"FAIL: expected sustained window type",! halt }
if +rs.%GetData(4) '= 2 { write !,"FAIL: expected sustained priority 2",! halt }
if rs.%GetData(5) '= "MEDIUM" { write !,"FAIL: expected sustained severity medium",! halt }
if rs.%GetData(6) = "" { write !,"FAIL: expected business message",! halt }
if rs.%GetData(7) '= "NEW" { write !,"FAIL: expected execution state new",! halt }

write !,"priority smoke passed",!
halt
EOF
	run_iris_session "$script_file"
	local status=$?
	rm -f "$script_file"
	return "$status"
}

echo "Requested test scope: ${TEST_SCOPE}"

if ! docker ps --format '{{.Names}}' | grep -qx "$IRIS_CONTAINER_NAME"; then
	echo "IRIS container ${IRIS_CONTAINER_NAME} is not running"
	exit 1
fi

case "$TEST_SCOPE" in
	budget)
		run_budget_test
		;;
	pos)
		run_budget_test
		run_pos_test
		;;
	gold)
		run_budget_test
		run_pos_test
		run_gold_test
		;;
	priority)
		run_budget_test
		run_priority_test
		;;
	rules)
		run_budget_test
		run_rules_test
		;;
	api)
		run_budget_test
		run_api_test
		;;
	all)
		run_budget_test
		run_pos_test
		run_gold_test
		run_priority_test
		run_rules_test
		run_api_test
		;;
	*)
		echo "Unknown test scope: ${TEST_SCOPE}"
		echo "Supported scopes: budget, pos, gold, all"
		exit 1
		;;
esac

echo "All requested tests passed"
