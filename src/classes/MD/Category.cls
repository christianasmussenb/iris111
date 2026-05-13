Class MD.Category Extends %Persistent
{

Property CategoryCode As %String(MAXLEN = 50) [ Required ];
Property CategoryName As %String(MAXLEN = 100);

Index CategoryCodeIdx On CategoryCode [ Unique ];

}
