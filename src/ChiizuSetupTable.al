table 50103 "Chiizu Setup"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            DataClassification = SystemMetadata;
        }
        field(10; "API Base URL"; Text[250]) { }
        field(30; "Webhook Secret"; Text[100]) { }
        field(40; "Test Mode"; Boolean) { }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
