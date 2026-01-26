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

        field(4; "Webhook Secret"; Text[100])
        {
            Caption = 'Webhook Secret';
            DataClassification = SystemMetadata;
        }
        field(20; "Payment Jnl. Template"; Code[10])
        {
            DataClassification = CustomerContent;
        }

        field(21; "Payment Jnl. Batch"; Code[10])
        {
            DataClassification = CustomerContent;
        }

    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
