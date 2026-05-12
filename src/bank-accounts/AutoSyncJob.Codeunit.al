codeunit 50112 "Chiizu Auto-Sync Job"
{
    trigger OnRun()
    var
        BankAcc: Record "Bank Account";
        BankAccRecon: Record "Bank Acc. Reconciliation";
        Setup: Record "Chiizu Setup";
        SetupMgmt: Codeunit "Chiizu Setup Management";
        TargetStatementNo: Code[20];
    begin
        // 1. Filter for accounts linked to Chiizu
        BankAcc.SetFilter("Chiizu Remote Balance", '>=%1', 0);
        if BankAcc.IsEmpty() then exit;

        if BankAcc.FindSet() then
            repeat
                // 2. Refresh the Remote Balance on the Bank Account card
                SetupMgmt.UpdateRemoteBalance(BankAcc);

                // 3. Determine the Statement Number
                TargetStatementNo := IncStr(BankAcc."Last Statement No.");
                if TargetStatementNo = '' then TargetStatementNo := '1';

                // 4. GET existing or CREATE new reconciliation header
                // We keep it open so the user can find it in the "Bank Acc. Reconciliation" list
                if not BankAccRecon.Get(BankAccRecon."Statement Type"::"Bank Reconciliation", BankAcc."No.", TargetStatementNo) then begin
                    BankAccRecon.Init();
                    BankAccRecon."Statement Type" := BankAccRecon."Statement Type"::"Bank Reconciliation";
                    BankAccRecon."Bank Account No." := BankAcc."No.";
                    BankAccRecon."Statement No." := TargetStatementNo;
                    // Note: ImportToBankReconciliation should update the Statement Ending Balance later
                    BankAccRecon.Insert(true);
                end;

                // 5. Import only the Statement Lines (Left Side)
                // Your duplicate check in this procedure ensures lines aren't added twice
                SetupMgmt.ImportToBankReconciliation(BankAccRecon);

            // --- MANUAL MATCHING MODE ---
            // We have removed MatchBankRecLines.BankAccReconciliationAutoMatch
            // and the balance check. The user will now open BC, see the lines,
            // and match them to Ledger Entries (Right Side) manually.

            until BankAcc.Next() = 0;

        // 6. Update Sync Status
        if Setup.Get('SETUP') then begin
            Setup."Last Sync Status" := 'Success';
            Setup."Last Sync Time" := CurrentDateTime();
            Setup.Modify();
        end;
    end;
}