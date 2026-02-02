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
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Get('SETUP');
    end;
}
