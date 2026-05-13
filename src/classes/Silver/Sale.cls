Class Silver.Sale Extends %Persistent
{

Property SaleId As %String(MAXLEN = 80) [ Required ];
Property SaleTimestamp As %TimeStamp [ Required ];
Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property InternalSKU As %String(MAXLEN = 50) [ Required ];
Property Qty As %Integer;
Property Price As %Numeric;
Property CategoryCode As %String(MAXLEN = 50);
Property SourceEventId As %String(MAXLEN = 80);

Index SaleIdIdx On SaleId [ Unique ];

}
