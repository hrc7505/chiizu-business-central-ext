page 50101 "Chiizu Assisted Setup"
{
    PageType = Card;
    SourceTable = "Chiizu Setup";
    ApplicationArea = All;
    Caption = 'Chiizu';

    layout
    {
        area(Content)
        {
            group(Connection)
            {
                Caption = 'Connection';

                field("API Base URL"; Rec."API Base URL")
                {
                    ApplicationArea = All;
                }

                field("API Key"; Rec."API Key")
                {
                    ApplicationArea = All;
                }

                field("Last Verified At"; Rec."Last Verified At")
                {
                    Caption = 'Last Connected At';
                    ApplicationArea = All;
                    Editable = false;
                }
            }

            group(SyncStatus)
            {
                Caption = 'Automation Status';
                Description = 'Shows the status of the automated synchronization with bank accounts and transactions.';
                Visible = Rec."Remote Tenant Id" <> '';

                field("Default Bank Posting Group"; Rec."Default Bank Posting Group")
                {
                    ApplicationArea = All;
                    ToolTip = 'Select the General Ledger posting group to automatically assign to new Chiizu Bank Accounts.';
                    ShowMandatory = true; // Puts a red star so the user knows they need to fill it out
                }
                field("Auto-Sync Enabled"; Rec."Auto-Sync Enabled")
                {
                    ApplicationArea = All;
                }
                field("Last Sync Time"; Rec."Last Sync Time")
                {
                    ApplicationArea = All;
                }
                field("Last Sync Status"; Rec."Last Sync Status")
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Connect)
            {
                Caption = 'Connect';
                Image = Link;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = Rec."Remote Tenant Id" = '';

                trigger OnAction()
                var
                    TenantId: Text;
                    ConnectionService: Codeunit "Chiizu Connection Service";
                begin
                    if Rec."API Base URL" = '' then
                        Error('API Base URL is required.');

                    if Rec."API Key" = '' then
                        Error('API Key is required.');

                    Rec."Remote Tenant Id" := ConnectionService.connect();
                    Rec."Last Verified At" := CurrentDateTime();
                    Rec.Modify(true);

                    Message('Chiizu connected successfully.');
                end;

            }

            action(Disconnect)
            {
                Caption = 'Disconnect';
                Image = UnLinkAccount;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                Visible = Rec."Remote Tenant Id" <> '';

                trigger OnAction()
                var
                    TenantId: Text;
                    ConnectionService: Codeunit "Chiizu Connection Service";
                begin
                    if ConnectionService.disconnect() then
                        Rec."Remote Tenant Id" := '';
                    Rec.Modify(true);
                    Message('Chiizu disconnected successfully.');
                end;
            }

            action(SelectFundingAccounts)
            {
                Caption = 'Select Funding Accounts';
                Image = BankAccount;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Visible = Rec."Remote Tenant Id" <> '';

                trigger OnAction()
                var
                    SetupMgmt: Codeunit "Chiizu Setup Management";
                    TempAllAcc: Record "Chiizu Funding Account" temporary;
                    TempSelectedAcc: Record "Chiizu Funding Account" temporary;
                    AccPage: Page "Chiizu Funding Account List";
                begin
                    SetupMgmt.FetchFundingAccounts(TempAllAcc);
                    AccPage.SetAccounts(TempAllAcc);
                    AccPage.LookupMode(true);

                    if AccPage.RunModal() = Action::LookupOK then begin
                        AccPage.GetSelectedRecords(TempSelectedAcc);
                        if TempSelectedAcc.FindSet() then
                            repeat
                                CreateBankAccountFromChiizu(TempSelectedAcc);
                            until TempSelectedAcc.Next() = 0;

                        // 🔹 AUTOMATION TRIGGER: Start the job after accounts are imported
                        StartSyncJob();

                        Message('%1 account(s) imported and auto-sync started.', TempSelectedAcc.Count());
                    end;
                end;
            }

            action(ForceSync)
            {
                Caption = 'Sync Now';
                Image = RefreshLines;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Visible = Rec."Remote Tenant Id" <> '';

                trigger OnAction()
                var
                    SyncJob: Codeunit "Chiizu Auto-Sync Job";
                begin
                    SyncJob.Run();
                    Message('Synchronization completed successfully.');
                end;
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec."Last Sync Status" = 'Success' then
            StatusStyle := 'Favorable'
        else if Rec."Last Sync Status" <> '' then
            StatusStyle := 'Unfavorable'
        else
            StatusStyle := 'None';
    end;

    trigger OnOpenPage()
    var
        setupMgmt: Codeunit "Chiizu Setup Management";
        Setup: Record "Chiizu Setup";
    begin
        setupMgmt.GetSetup(Setup);
    end;

    // Inside Page 50101
    local procedure CreateBankAccountFromChiizu(ChiizuAcc: Record "Chiizu Funding Account" temporary)
    var
        BankAcc: Record "Bank Account";
        SetupMgmt: Codeunit "Chiizu Setup Management";
    begin
        if BankAcc.Get(ChiizuAcc."Account Id") then
            exit;

        // 🔹 SAFETY CHECK: Ensure they picked a group before we try to create accounts
        Rec.TestField("Default Bank Posting Group");

        BankAcc.Init();
        BankAcc."No." := ChiizuAcc."Account Id";
        BankAcc.Name := ChiizuAcc.Name;
        BankAcc."Bank Account No." := ChiizuAcc."Account Number";
        BankAcc."Currency Code" := ChiizuAcc."Currency Code";

        // 🔹 DYNAMIC ASSIGNMENT
        BankAcc.Validate("Bank Acc. Posting Group", Rec."Default Bank Posting Group");

        BankAcc.Insert(true);

        SetupMgmt.UpdateRemoteBalance(BankAcc);
    end;

    // Add this helper to the bottom of the page
    local procedure StartSyncJob()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"Chiizu Auto-Sync Job");

        if JobQueueEntry.IsEmpty() then begin
            JobQueueEntry.Init();
            JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
            JobQueueEntry."Object ID to Run" := Codeunit::"Chiizu Auto-Sync Job";
            JobQueueEntry."Earliest Start Date/Time" := CurrentDateTime();

            // --- Frequency: 10 Minutes ---
            JobQueueEntry."Recurring Job" := true;
            JobQueueEntry."No. of Minutes between Runs" := 10;

            // --- Daily Recurrence (Every Day) ---
            JobQueueEntry."Run on Mondays" := true;
            JobQueueEntry."Run on Tuesdays" := true;
            JobQueueEntry."Run on Wednesdays" := true;
            JobQueueEntry."Run on Thursdays" := true;
            JobQueueEntry."Run on Fridays" := true;
            JobQueueEntry."Run on Saturdays" := true;
            JobQueueEntry."Run on Sundays" := true;

            // Enqueue the job immediately
            Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
        end else begin
            // Ensure existing job is active and enabled
            JobQueueEntry.FindFirst();
            if JobQueueEntry.Status = JobQueueEntry.Status::"On Hold" then
                JobQueueEntry.Restart();
        end;

        // Update Setup record to reflect automation is active
        Rec."Auto-Sync Enabled" := true;
        Rec.Modify();
    end;
}
