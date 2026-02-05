table 50110 "Chiizu Invoice Status"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Invoice No."; Code[20])
        {
            DataClassification = CustomerContent;
        }

        // Enum lifecycle
        field(2; Status; Enum "Chiizu Payment Status")
        {
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                if AllowSystemUpdate then
                    exit;

                // 🔒 BC owns final truth for Paid statuses
                if (Status in [Status::Paid, Status::"Partially Paid"])
                then
                    Error(
                        'Status %1 is derived from Business Central ledger and cannot be set manually.',
                        Status
                    );
            end;
        }

        // For scheduled payments
        field(6; "Scheduled Date"; Date)
        {
            DataClassification = CustomerContent;
        }

        // Webhook matching
        field(7; "Batch Id"; Code[20])
        {
            DataClassification = SystemMetadata;
        }

        // Journal reference
        field(8; "Last Payment Reference"; Code[50])
        {
            DataClassification = CustomerContent;
        }

        // Audit
        field(9; "Last Updated At"; DateTime)
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

    var
        AllowSystemUpdate: Boolean;

    procedure SetStatusSystem(NewStatus: Enum "Chiizu Payment Status"; NewScheduledDate: Date)
    begin
        AllowSystemUpdate := true;
        Status := NewStatus;
        "Scheduled Date" := NewScheduledDate;
        Modify(true);
        AllowSystemUpdate := false;
    end;

}
