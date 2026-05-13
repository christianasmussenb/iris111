Class MD.Store Extends %Persistent
{

Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property StoreName As %String(MAXLEN = 100);
Property Region As %String(MAXLEN = 50);
Property District As %String(MAXLEN = 50);
Property TimeZone As %String(MAXLEN = 50);

Index StoreCodeIdx On StoreCode [ Unique ];

}
