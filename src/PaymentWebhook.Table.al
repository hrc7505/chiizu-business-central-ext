table 50149 "Chiizu Payment Webhook"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
        }

        field(2; "Batch Id"; Code[50]) { }

        field(3; Status; Enum "Chiizu Payment Status") { }

        field(4; "Payment Reference"; Code[50]) { }

        field(5; "Received At"; DateTime) { }

        field(40; "Webhook Secret"; Text[100]) { }

        field(10; Signature; Text[100])
        {
            Caption = 'Signature';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        Processor: Codeunit "Chiizu Payment Processor";
        RecCopy: Record "Chiizu Payment Webhook";
        WebhookVerifier: Codeunit "Chiizu Webhook Verifier";
    begin
        // 1️⃣ Verify FIRST
        WebhookVerifier.Verify(Rec);

        // 2️⃣ System timestamp
        "Received At" := CurrentDateTime();

        // 3️⃣ Use copy (safe pattern)
        RecCopy := Rec;

        // 4️⃣ Process webhook
        Processor.Run(RecCopy);
    end;

}
