namespace Chiizu.Installation;

using Chiizu;
using Chiizu.BankAccounts;

page 1000001 "Chiizu Assisted Setup"
{
    PageType = Card;
    SourceTable = "Chiizu Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
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
                    ToolTip = 'Specifies the base URL for the Chiizu API.';
                }

                field("API Key"; Rec."API Key")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API key for authentication.';
                }

                field("Last Verified At"; Rec."Last Verified At")
                {
                    Caption = 'Last Connected At';
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time the connection was last verified.';
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
                    ToolTip = 'Specifies whether automatic synchronization is enabled.';
                }
                field("Last Sync Time"; Rec."Last Sync Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the time of the most recent sync operation.';
                }
                field("Last Sync Status"; Rec."Last Sync Status")
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the status of the most recent sync operation.';
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
                PromotedOnly = true;
                Visible = Rec."Remote Tenant Id" = '';
                ToolTip = 'Connect your Chiizu account to Business Central.';

                trigger OnAction()
                var
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
                PromotedOnly = true;
                Visible = Rec."Remote Tenant Id" <> '';
                ToolTip = 'Disconnect your Chiizu account from Business Central.';

                trigger OnAction()
                var
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
                PromotedOnly = true;
                Visible = Rec."Remote Tenant Id" <> '';
                ToolTip = 'Select and import funding accounts from Chiizu.';

                trigger OnAction()
                var
                    TempAllAcc: Record "Chiizu Funding Account" temporary;
                    TempSelectedAcc: Record "Chiizu Funding Account" temporary;
                    SetupMgmt: Codeunit "Chiizu Setup Management";
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
                PromotedOnly = true;
                Visible = Rec."Remote Tenant Id" <> '';
                ToolTip = 'Trigger an immediate synchronization with Chiizu.';

                trigger OnAction()
                begin
                    // TODO: Implement force sync
                    Message('Force sync not implemented yet.');
                end;
            }

            action(ViewLogs)
            {
                ToolTip = 'View the detailed history of the 10-minute automated sync runs.';
                Caption = 'View Sync History';
                Image = Log;
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                RunObject = Page "Chiizu Sync Log";
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec."Last Sync Status" = 'Success' then
            StatusStyle := 'Favorable'
        else
            if Rec."Last Sync Status" <> '' then
                StatusStyle := 'Unfavorable'
            else
                StatusStyle := 'None';
    end;

    trigger OnOpenPage()
    var
        Setup: Record "Chiizu Setup";
        setupMgmt: Codeunit "Chiizu Setup Management";
    begin
        setupMgmt.GetSetup(Setup);
    end;
}
