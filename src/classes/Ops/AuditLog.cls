Class Ops.AuditLog Extends %Persistent
{

Property EventId As %String(MAXLEN = 80) [ Required ];
Property EntityName As %String(MAXLEN = 100) [ Required ];
Property EntityId As %String(MAXLEN = 80) [ Required ];
Property ActionType As %String(MAXLEN = 50) [ Required ];
Property BeforeState As %String(MAXLEN = 5000);
Property AfterState As %String(MAXLEN = 5000);
Property CreatedAt As %TimeStamp;
Property CreatedBy As %String(MAXLEN = 100);

Index EventIdIdx On EventId [ Unique ];

}
