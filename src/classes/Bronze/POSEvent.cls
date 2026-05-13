Class Bronze.POSEvent Extends %Persistent
{

Property SourceId As %String(MAXLEN = 80) [ Required ];
Property ReceivedAt As %TimeStamp [ Required ];
Property SourceChannel As %String(MAXLEN = 20);
Property Payload As %String(MAXLEN = 5000) [ Required ];

Index SourceIdIdx On SourceId [ Unique ];

}
