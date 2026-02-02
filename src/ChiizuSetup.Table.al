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
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
