Class Ops.Recommendation Extends %Persistent
{

Property RecommendationId As %String(MAXLEN = 80) [ Required ];
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property RuleFired As %String(MAXLEN = 50) [ Required ];
Property RuleWindowType As %String(MAXLEN = 20);
Property RuleThreshold As %Numeric;
Property RuleObservedValue As %Numeric;
Property RulePriority As %Integer;
Property RuleSeverity As %String(MAXLEN = 20);
Property BusinessMessage As %String(MAXLEN = 500);
Property ExecutionState As %String(MAXLEN = 20) [ InitialExpression = "NEW" ];
Property RelatedPaceId As %String(MAXLEN = 80);
Property ActionCode As %String(MAXLEN = 50) [ Required ];
Property ActionDescription As %String(MAXLEN = 500);
Property Status As %String(MAXLEN = 20) [ InitialExpression = "PENDING" ];
Property TriggeredAt As %TimeStamp;
Property AcceptedBy As %String(MAXLEN = 100);
Property AcceptedAt As %TimeStamp;
Property ExecutedAt As %TimeStamp;
Property EffectivenessScore As %Numeric;
Property Notes As %String(MAXLEN = 1000);

Index RecommendationIdIdx On RecommendationId [ Unique ];

Storage Default
{
<Data name="RecommendationDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>RecommendationId</Value>
</Value>
<Value name="3">
<Value>StoreCode</Value>
</Value>
<Value name="4">
<Value>CategoryCode</Value>
</Value>
<Value name="5">
<Value>RuleFired</Value>
</Value>
<Value name="6">
<Value>RuleWindowType</Value>
</Value>
<Value name="7">
<Value>RuleThreshold</Value>
</Value>
<Value name="8">
<Value>RuleObservedValue</Value>
</Value>
<Value name="9">
<Value>RulePriority</Value>
</Value>
<Value name="10">
<Value>RuleSeverity</Value>
</Value>
<Value name="11">
<Value>BusinessMessage</Value>
</Value>
<Value name="12">
<Value>ExecutionState</Value>
</Value>
<Value name="13">
<Value>RelatedPaceId</Value>
</Value>
<Value name="14">
<Value>ActionCode</Value>
</Value>
<Value name="15">
<Value>ActionDescription</Value>
</Value>
<Value name="16">
<Value>Status</Value>
</Value>
<Value name="17">
<Value>TriggeredAt</Value>
</Value>
<Value name="18">
<Value>AcceptedBy</Value>
</Value>
<Value name="19">
<Value>AcceptedAt</Value>
</Value>
<Value name="20">
<Value>ExecutedAt</Value>
</Value>
<Value name="21">
<Value>EffectivenessScore</Value>
</Value>
<Value name="22">
<Value>Notes</Value>
</Value>
</Data>
<DataLocation>^Ops.RecommendationD</DataLocation>
<DefaultData>RecommendationDefaultData</DefaultData>
<IdLocation>^Ops.RecommendationD</IdLocation>
<IndexLocation>^Ops.RecommendationI</IndexLocation>
<StreamLocation>^Ops.RecommendationS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
