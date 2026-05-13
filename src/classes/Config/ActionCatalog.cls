Class Config.ActionCatalog Extends %Persistent
{

Property ActionCode As %String(MAXLEN = 50) [ Required ];
Property ActionName As %String(MAXLEN = 100);
Property Channel As %String(MAXLEN = 20);
Property Description As %String(MAXLEN = 500);
Property IsActive As %Boolean [ InitialExpression = 1 ];

Index ActionCodeIdx On ActionCode [ Unique ];

}
