table 50110 "Chiizu Invoice Status"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Invoice No."; Code[20])
        {
            DataClassification = CustomerContent;
        }

        field(2; "Paid via Chiizu"; Boolean)
        {
            DataClassification = CustomerContent;
        }

        field(3; "Payment Date"; Date)
        {
            DataClassification = CustomerContent;
        }

        field(4; "Transaction Id"; Code[50])
        {
            DataClassification = CustomerContent;
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
