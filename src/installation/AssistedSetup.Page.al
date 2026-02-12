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
                    // 1. Fetch from API
                    SetupMgmt.FetchFundingAccounts(TempAllAcc);

                    // 2. Load the page buffer
                    AccPage.SetAccounts(TempAllAcc);
                    AccPage.LookupMode(true);

                    if AccPage.RunModal() = Action::LookupOK then begin
                        // 3. Extract the native selection
                        AccPage.GetSelectedRecords(TempSelectedAcc);

                        if TempSelectedAcc.FindSet() then
                            repeat
                                CreateBankAccountFromChiizu(TempSelectedAcc);
                            until TempSelectedAcc.Next() = 0;

                        Message('%1 account(s) imported successfully.', TempSelectedAcc.Count());
                    end;
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        setupMgmt: Codeunit "Chiizu Setup Management";
        Setup: Record "Chiizu Setup";
    begin
        setupMgmt.GetSetup(Setup);
    end;

    local procedure CreateBankAccountFromChiizu(ChiizuAcc: Record "Chiizu Funding Account" temporary)
    var
        BankAcc: Record "Bank Account";
    begin
        // 🔹 HARD CHECK: Exit if the account already exists to prevent errors
        if BankAcc.Get(ChiizuAcc."Account Id") then
            exit;

        BankAcc.Init();
        BankAcc."No." := ChiizuAcc."Account Id"; // Using Account Id as the primary key
        BankAcc.Name := ChiizuAcc.Name;
        BankAcc."Bank Account No." := ChiizuAcc."Account Number";
        BankAcc."Currency Code" := ChiizuAcc."Currency Code";

        // true ensures that standard BC logic (like No. Series) is respected if needed
        BankAcc.Insert(true);
    end;
}
