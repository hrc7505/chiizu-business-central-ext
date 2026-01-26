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
        BatchId: Code[20];
        Status: Enum "Chiizu Payment Status";
        PaymentRef: Code[50]
    )
    var
        Batch: Record "Chiizu Payment Batch";
        WebhookLog: Record "Chiizu Payment Webhook Log";
    begin
        // 🔒 Idempotency
        WebhookLog.Reset();
        WebhookLog.SetRange("Batch Id", BatchId);
        WebhookLog.SetRange(Status, Status);
        if WebhookLog.FindFirst() then
            exit;

        // 📝 Log webhook reception
        WebhookLog.Init();
        WebhookLog."Batch Id" := BatchId;
        WebhookLog.Status := Status;
        WebhookLog."Payment Reference" := PaymentRef;
        WebhookLog."Received At" := CurrentDateTime();
        WebhookLog.Insert(true);

        if not Batch.Get(BatchId) then
            Error('Payment batch %1 not found.', BatchId);

        case Status of
            Status::Paid:
                begin
                    if Batch.Status = Status::ExternalPaid then
                        exit;

                    // 💰 Post payment via Gen. Journal
                    CreateAndPostPaymentLines(Batch);

                    // ✅ Update batch AFTER successful posting
                    Batch.Status := Status::ExternalPaid;
                    Batch."Payment Reference" := PaymentRef;
                    Batch."Posted At" := CurrentDateTime();
                    Batch.Modify(true);
                end;

            Status::Failed:
                begin
                    if Batch.Status <> Status::Failed then begin
                        Batch.Status := Status::Failed;
                        Batch.Modify(true);
                    end;
                end;
        end;
    end;

    local procedure CreateAndPostPaymentLines(Batch: Record "Chiizu Payment Batch")
    var
        PostingHelper: Codeunit "Chiizu Payment Posting Helper";
    begin
        PostingHelper.PostPayment(Batch);
    end;

}
