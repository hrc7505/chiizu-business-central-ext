codeunit 50141 "Chiizu Payment Processor"
{
    procedure Run(Webhook: Record "Chiizu Payment Webhook")
    var
        InvoiceStatus: Record "Chiizu Invoice Status";
    begin
        if not InvoiceStatus.Get(Webhook."Invoice No.") then
            Error('Invoice %1 not found.', Webhook."Invoice No.");

        InvoiceStatus."Batch Id" := Webhook."Payment Intent Id";
        InvoiceStatus."Last Payment Reference" := Webhook."Payment Reference";
        InvoiceStatus."Last Updated At" := CurrentDateTime();

        InvoiceStatus.SetStatusSystem(
            Webhook.Status,
            0D
        );
    end;

    local procedure ProcessWebhook(BatchId: Code[50]; Status: Enum "Chiizu Payment Status"; PaymentRef: Code[50])
    var
        Batch: Record "Chiizu Payment Batch";
        WebhookLog: Record "Chiizu Payment Webhook Log";
    begin
        // 🔒 Idempotency check
        if WebhookLog.Get(BatchId, Status, PaymentRef) then
            exit;

        // Log webhook
        WebhookLog.Init();
        WebhookLog."Batch Id" := BatchId;
        WebhookLog.Status := Status;
        WebhookLog."Payment Reference" := PaymentRef;
        WebhookLog."Received At" := CurrentDateTime();
        WebhookLog.Insert(true);

        // Load batch
        if not Batch.Get(BatchId) then
            Error('Payment batch %1 not found.', BatchId);

        case Status of
            Enum::"Chiizu Payment Status"::Paid:
                begin
                    // 🚨 SAFETY: only post once
                    if Batch.Status <> Enum::"Chiizu Payment Status"::ExternalPaid then begin
                        CreateAndPostPaymentLines(Batch);

                        Batch.Status := Enum::"Chiizu Payment Status"::ExternalPaid;
                        Batch."Payment Reference" := PaymentRef;
                        Batch."Posted At" := CurrentDateTime();
                        Batch.Modify(true);
                    end;
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
        if Batch."Total Amount" = 0 then
            Error('Cannot post zero-amount payment for batch %1.', Batch."Batch Id");

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
