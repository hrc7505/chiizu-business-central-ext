codeunit 50112 "Chiizu Auto-Sync Job"
{
    trigger OnRun()
    var
        BankAcc: Record "Bank Account";
        BankAccRecon: Record "Bank Acc. Reconciliation";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        MatchBankRecLines: Codeunit "Match Bank Rec. Lines"; // Standard BC logic
    begin
        if BankAcc.FindSet() then
            repeat
                // 1. Sync Balance
                SetupMgmt.UpdateRemoteBalance(BankAcc);

                // 2. Prepare/Find Reconciliation Worksheet
                BankAccRecon.SetRange("Bank Account No.", BankAcc."No.");
                if not BankAccRecon.FindFirst() then begin
                    BankAccRecon.Init();
                    BankAccRecon."Statement Type" := BankAccRecon."Statement Type"::"Bank Reconciliation";
                    BankAccRecon."Bank Account No." := BankAcc."No.";
                    BankAccRecon."Statement No." := BankAcc."Last Statement No." + '1';
                    BankAccRecon.Insert();
                end;

                // 3. Import Transactions from Chiizu
                SetupMgmt.ImportToBankReconciliation(BankAccRecon);

                // 4. THE NEXT STEP: Auto-Match
                // This triggers BC's internal logic to match by Date/Amount
                MatchBankRecLines.BankAccReconciliationAutoMatch(BankAccRecon, 1); // 1 = Days of tolerance

            until BankAcc.Next() = 0;
    end;
}