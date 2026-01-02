table 50110 "Chiizu Invoice Status"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Invoice No."; Code[20])
        {
            DataClassification = CustomerContent;
        }

        field(2; Status; Enum "Chiizu Payment Status")
        {
            DataClassification = CustomerContent;
        }

        field(3; "Vendor No."; Code[20])
        {
            DataClassification = CustomerContent;
        }

        field(4; Amount; Decimal)
        {
            DataClassification = CustomerContent;
        }

        field(5; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Invoice No.")
        {
            Clustered = true;
        }
    }
}
