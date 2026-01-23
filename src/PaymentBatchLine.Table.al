table 50142 "Chiizu Payment Batch Line"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Batch Id"; Code[50]) { }
        field(2; "Line No."; Integer) { }
        field(3; "Invoice No."; Code[20]) { }
        field(4; "Vendor No."; Code[20]) { }
        field(5; Amount; Decimal) { }
        field(6; "Remaining Amount"; Decimal) { }
    }

    keys
    {
        key(PK; "Batch Id", "Line No.")
        {
            Clustered = true;
        }
    }
}
