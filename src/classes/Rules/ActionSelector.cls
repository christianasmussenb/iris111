Class Rules.ActionSelector
{

ClassMethod SelectAction(ruleCode As %String) As %String
{
    Set ruleCode = $ZCONVERT(ruleCode, "U")

    If ruleCode = "PACE_NEGATIVE_CRITICAL" Quit "MOVE_PALLET_TO_ENTRY"
    If ruleCode = "PACE_NEGATIVE_SUSTAINED" Quit "ACTIVATE_PROMOTION"
    If ruleCode = "STOCKOUT_INFERRED" Quit "REFRESH_SHELF_DISPLAY"

    Quit "REVIEW_MANUALLY"
}

}
