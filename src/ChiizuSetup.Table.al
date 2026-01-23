table 50103 "Chiizu Setup"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            DataClassification = SystemMetadata;
        }
        field(2; "API Base URL"; Text[250]) { }

        field(3; "Webhook URL"; Text[250]) { }

        field(4; "Webhook Secret"; Text[100])
        {
            Caption = 'Webhook Secret';
            DataClassification = SystemMetadata;
        }

    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
