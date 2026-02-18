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

        field(10; "Last Batch No."; Integer) { }

        field(12; "API Key"; Text[250])
        {
            ExtendedDatatype = Masked;
        }

        field(30; "Last Verified At"; DateTime) { }
        // returned by Chiizu API
        field(40; "Remote Tenant Id"; Text[100]) { }

        // Auto-sync fields for bank account balance and transactions reconciliation status
        field(50; "Auto-Sync Enabled"; Boolean)
        {
            Caption = 'Auto-Sync Enabled';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(51; "Last Sync Status"; Text[100])
        {
            Caption = 'Last Sync Status';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(52; "Last Sync Time"; DateTime)
        {
            Caption = 'Last Sync Time';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(53; "Default Bank Posting Group"; Code[20])
        {
            Caption = 'Default Bank Posting Group';
            TableRelation = "Bank Account Posting Group";
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
