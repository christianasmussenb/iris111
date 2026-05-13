Class Ops.Recommendation Extends %Persistent
{

Property RecommendationId As %String(MAXLEN = 80) [ Required ];
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property RuleFired As %String(MAXLEN = 50) [ Required ];
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

}
