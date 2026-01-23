codeunit 50141 "Chiizu Payment Processor"
{
    procedure Run(var WebhookRec: Record "Chiizu Payment Webhook")
    begin
        ProcessWebhook(
            WebhookRec."Batch Id",
            WebhookRec.Status,
            WebhookRec."Payment Reference"
        );
    end;

    local procedure ProcessWebhook(
        BatchId: Code[50];
        Status: Enum "Chiizu Payment Status";
        PaymentRef: Code[50]
    )
    var
        Batch: Record "Chiizu Payment Batch";
    begin
        if not Batch.Get(BatchId) then
            Error('Payment batch %1 not found.', BatchId);

        // 🔒 Idempotency protection
        if Batch.Status = Enum::"Chiizu Payment Status"::Paid then
            exit;

        case Status of
            Enum::"Chiizu Payment Status"::ExternalPaid:
                begin
                    CreateAndPostPaymentLines(Batch);

                    Batch.Status := Enum::"Chiizu Payment Status"::Paid;
                    Batch."Payment Reference" := PaymentRef;
                    Batch."Posted At" := CurrentDateTime();
                    Batch.Modify(true);
                end;

            Enum::"Chiizu Payment Status"::Failed:
                begin
                    Batch.Status := Enum::"Chiizu Payment Status"::Failed;
                    Batch.Modify(true);
                end;
        end;
    end;

    local procedure CreateAndPostPaymentLines(Batch: Record "Chiizu Payment Batch")
    var
        GenJnlLine: Record "Gen. Journal Line";
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
        PostingHelper: Codeunit "Chiizu Payment Posting Helper";
    begin
        PostingHelper.PostBatch(Batch);
        GenJnlLine.Init();
        GenJnlLine.Validate("Journal Template Name", 'PAYMENTS');
        GenJnlLine.Validate("Journal Batch Name", 'DEFAULT');
        GenJnlLine.Validate("Document Type", GenJnlLine."Document Type"::Payment);
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Vendor);
        GenJnlLine.Validate("Account No.", Batch."Vendor No.");
        GenJnlLine.Validate(Amount, -Batch."Total Amount");
        GenJnlLine.Validate("Posting Date", Today());
        GenJnlLine."External Document No." := Batch."Payment Reference";
        GenJnlLine.Insert(true);

        GenJnlPost.Run(GenJnlLine);
    end;
}
