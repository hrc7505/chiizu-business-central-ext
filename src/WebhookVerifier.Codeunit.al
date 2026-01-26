codeunit 50138 "Chiizu Webhook Verifier"
{
    procedure Verify(Webhook: Record "Chiizu Payment Webhook")
    var
        Setup: Record "Chiizu Setup";
        Crypto: Codeunit "Cryptography Management";
        Payload: Text;
        ComputedSignature: Text;
    begin
        if not Setup.Get() then
            Error('Chiizu Setup not found.');

        Payload :=
            Webhook."Batch Id" +
            Format(Webhook.Status) +
            Webhook."Payment Reference";

        // 0 = SHA256
        ComputedSignature :=
            Crypto.GenerateHash(Payload + Setup."Webhook Secret", 0);

        if LowerCase(ComputedSignature) <> LowerCase(Webhook.Signature) then
            Error('Invalid webhook signature.');
    end;
}
