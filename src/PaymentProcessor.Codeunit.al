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
        // 🔒 STRONG idempotency (Batch + Status)
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

        // 🔍 Always fetch fresh DB record
        if not Batch.Get(BatchId) then
            Error('Payment batch %1 not found.', BatchId);

        case Status of
            Enum::"Chiizu Payment Status"::Paid:
                begin
                    // ✅ Idempotent guard
                    if Batch.Status = Enum::"Chiizu Payment Status"::ExternalPaid then
                        exit;

                    // 💰 Post payment FIRST
                    CreateAndPostPaymentLines(Batch);

                    // ✅ Update batch AFTER successful posting
                    Batch.Status := Enum::"Chiizu Payment Status"::ExternalPaid;
                    Batch."Payment Reference" := PaymentRef;
                    Batch."Posted At" := CurrentDateTime();
                    Batch.Modify(true);
                end;

            Enum::"Chiizu Payment Status"::Failed:
                begin
                    if Batch.Status <> Enum::"Chiizu Payment Status"::Failed then begin
                        Batch.Status := Enum::"Chiizu Payment Status"::Failed;
                        Batch.Modify(true);
                    end;
                end;
        end;
    end;

    local procedure CreateAndPostPaymentLines(Batch: Record "Chiizu Payment Batch")
    var
        PostingHelper: Codeunit "Chiizu Payment Posting Helper";
    begin
        PostingHelper.PostBatch(Batch);
    end;
}
