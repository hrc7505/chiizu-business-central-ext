table 50130 "Chiizu Payment Batch"
{
    DataClassification = SystemMetadata;
    Caption = 'Chiizu Payment Batch';

    fields
    {
        field(1; "Batch Id"; Code[50])
        {
            Caption = 'Batch Id';
        }

        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
        }

        field(3; "Total Amount"; Decimal)
        {
            Caption = 'Total Amount';
        }

        field(4; Status; Enum "Chiizu Payment Status")
        {
            Caption = 'Status';
        }

        field(5; "Payment Reference"; Text[50])
        {
            Caption = 'Payment Reference';
        }

        field(6; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }

        field(7; "Posted At"; DateTime)
        {
            Caption = 'Posted At';
        }
        field(20; "Invoice No."; Code[20])
        {
            DataClassification = CustomerContent;
        }

    }

    keys
    {
        key(PK; "Batch Id")
        {
            Clustered = true;
        }
    }
}
