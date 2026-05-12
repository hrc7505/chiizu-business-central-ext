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
                                // 🔹 CALL THE NEW AUTOMATED FUNCTION
                                SetupMgmt.CreateBankAccountFromChiizuV2(TempSelectedAcc);
                            until TempSelectedAcc.Next() = 0;

                        Message('%1 account(s) imported and configured successfully.', TempSelectedAcc.Count());
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
            }

            action(ViewLogs)
            {
                Caption = 'View Sync History';
                Image = Log;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = Page "Chiizu Sync Log";
                ToolTip = 'View the detailed history of the 10-minute automated sync runs.';
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
}
