table 50121 "Chiizu Scheduled Payment"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
        }

        field(2; "Invoice No."; Code[20]) { }
        field(3; "Vendor No."; Code[20]) { }
        field(4; Amount; Decimal) { }
        field(5; "Scheduled Date"; Date) { }

        field(6; Status; Enum "Chiizu Payment Status") { }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }
}
