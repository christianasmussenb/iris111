Class MD.SKU Extends %Persistent
{

Property InternalSKU As %String(MAXLEN = 50) [ Required ];
Property VendorSKU As %String(MAXLEN = 50);
Property CategoryCode As %String(MAXLEN = 50);
Property UnitOfMeasure As %String(MAXLEN = 20);

Index InternalSKUIdx On InternalSKU [ Unique ];

}
