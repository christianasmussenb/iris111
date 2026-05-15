Class MD.SKUPrice Extends %Persistent
{

Property StoreCode As %String(MAXLEN = 20) [ Required ];
Property InternalSKU As %String(MAXLEN = 50) [ Required ];
Property EffectiveStartDate As %Date(FORMAT = 3) [ Required ];
Property EffectiveEndDate As %Date(FORMAT = 3);
Property Price As %Numeric [ Required ];
Property Currency As %String(MAXLEN = 3) [ InitialExpression = "COP" ];
Property LoadedAt As %TimeStamp;

Index PriceKeyIdx On (StoreCode, InternalSKU, EffectiveStartDate) [ Unique ];

Method %OnValidate() As %Status
{
	If ..StoreCode = "" {
		Quit $SYSTEM.Status.Error(5001, "StoreCode is required")
	}

	If ..InternalSKU = "" {
		Quit $SYSTEM.Status.Error(5001, "InternalSKU is required")
	}

	If ..EffectiveStartDate = "" {
		Quit $SYSTEM.Status.Error(5001, "EffectiveStartDate is required")
	}

	If ..EffectiveEndDate'="", ..EffectiveEndDate < ..EffectiveStartDate {
		Quit $SYSTEM.Status.Error(5001, "EffectiveEndDate must be greater than or equal to EffectiveStartDate")
	}

	If ..Price < 0 {
		Quit $SYSTEM.Status.Error(5001, "Price must be greater than or equal to zero")
	}

	Quit $$$OK
}

Storage Default
{
<Data name="SKUPriceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>StoreCode</Value>
</Value>
<Value name="3">
<Value>InternalSKU</Value>
</Value>
<Value name="4">
<Value>EffectiveStartDate</Value>
</Value>
<Value name="5">
<Value>EffectiveEndDate</Value>
</Value>
<Value name="6">
<Value>Price</Value>
</Value>
<Value name="7">
<Value>Currency</Value>
</Value>
<Value name="8">
<Value>LoadedAt</Value>
</Value>
</Data>
<DataLocation>^MD.SKUPriceD</DataLocation>
<DefaultData>SKUPriceDefaultData</DefaultData>
<IdLocation>^MD.SKUPriceD</IdLocation>
<IndexLocation>^MD.SKUPriceI</IndexLocation>
<StreamLocation>^MD.SKUPriceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}