codeunit 50141 "Chiizu Payment Processor"
{
    // 🔑 PUBLIC ENTRY POINT (called from table trigger or webhook handler)
    procedure Run(var WebhookRec: Record "Chiizu Payment Webhook")
    begin
        ProcessWebhook(
            WebhookRec."Batch Id",
            WebhookRec.Status,
            WebhookRec."Payment Reference",
            WebhookRec."Bank Account No."
        );
    end;

    local procedure ProcessWebhook(BatchId: Code[50]; Status: Enum "Chiizu Payment Status"; PaymentRef: Code[50]; BankAccountNo: Code[20])
    var
        Batch: Record "Chiizu Payment Batch";
        PostingHelper: Codeunit "Chiizu Payment Posting Helper";
    begin
        if not Batch.Get(BatchId) then
            Error('Batch %1 not found.', BatchId);

        case Status of
            Status::Paid:
                begin
                    Batch.Status := Status::Paid;
                    Batch."Payment Reference" := PaymentRef;
                    Batch.Modify(true);

                    // ✅ Correct signature (ONLY batch)
                    PostingHelper.PostBatch(Batch, BankAccountNo);
                end;

            Status::Failed:
                begin
                    Batch.Status := Status::Failed;
                    Batch.Modify(true);
                end;
        end;
    end;
}
