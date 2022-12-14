// Highly inspired from the plugin "Royal Match Monitor" made by "jeFFeSS"
// https://openplanet.dev/plugin/royalmatchmonitor

// Global state
string g_pluginName = "\\$fd0" + Icons::Trophy + "\\$z Royal match info";

bool g_isWindowOpened = true;
bool g_hasChatPermission = true;
bool g_showPlayers = false;
uint64 g_lastMsgSentAt = 0;

void Main() {
    NadeoServices::AddAudience("NadeoClubServices");
    while (!NadeoServices::IsAuthenticated("NadeoClubServices")) {
        yield();
    }

    g_hasChatPermission = Permissions::InGameChat();
}

void RenderMenu() {
    if (UI::MenuItem(g_pluginName, "", g_isWindowOpened, NadeoServices::IsAuthenticated("NadeoClubServices"))) {
		g_isWindowOpened = !g_isWindowOpened;
	}
}

void RenderInterface() {
    if (!g_isWindowOpened || !NadeoServices::IsAuthenticated("NadeoClubServices"))
        return;

    // Trackmania API and computed variables
    auto app = cast<CTrackMania>(GetApp());
    if (app is null)
        return;

    auto network = cast<CTrackManiaNetwork>(app.Network);
    if (network is null)
        return;

    auto tmpServer = cast<CTrackManiaNetworkServerInfo>(network.ServerInfo);
    if (tmpServer is null)
        return;
    
    CTrackManiaNetworkServerInfo@ currentServer;
    for (uint i = 0; i < network.OnlineServers.Length; i++) {
        auto serverInfo = cast<CTrackManiaNetworkServerInfo>(network.OnlineServers[i]);
        if (tmpServer.ServerLogin == serverInfo.ServerLogin) {
            @currentServer = serverInfo;
            break;
        }
    }
    if (currentServer is null || !IsRoyalServer(currentServer))
        return;

    auto playground = cast<CGamePlaygroundCommon>(app.CurrentPlayground);
    if (playground is null || playground.GameTerminals.Length < 1 || playground.GameTerminals[0].ControlledPlayer is null)
        return;

    auto playgroundInterface = cast<CGamePlaygroundInterface>(playground.Interface);
    auto timeSinceLastMsgSent = Time::get_Now() - g_lastMsgSentAt;
    auto canUseChat = g_hasChatPermission && playgroundInterface !is null && timeSinceLastMsgSent > 5000;

    // Begin window
    UI::SetNextWindowSize(400, 100);
    UI::Begin(g_pluginName, g_isWindowOpened, UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize);

    // Display maps
    UI::TextWrapped(GetMapNamesForUI(currentServer));

    // Copy map names to clipboard
    if (GrayButton(Icons::Clipboard + " Copy")) {
        IO::SetClipboard(GetMapNamesForClipboard(currentServer));
        Notify("Map names copied to clipboard", 3000);
    }

    // Send map names to global chat
    if (!canUseChat) {
        UI::BeginDisabled();
    }

    UI::SameLine();
    if (BlueButton((canUseChat ? Icons::Bullhorn : Icons::Lock) + " Send to chat")) {
        playgroundInterface.ChatEntry = GetMapNamesForChat(currentServer);
        g_lastMsgSentAt = Time::get_Now();
    }

    // Send map names to team chat
    UI::SameLine();
    if (BlueButton((canUseChat ? Icons::UserSecret : Icons::Lock) + " Send to team")) {
        playgroundInterface.ChatEntry = "/t " + GetMapNamesForChat(currentServer);
        g_lastMsgSentAt = Time::get_Now();
    }

    if (!canUseChat) {
        UI::EndDisabled();
    }
    
    // Toggle players name display
    UI::SameLine();
    if (GreenButton("Show players " + (g_showPlayers ? Icons::CaretUp : Icons::CaretDown))) {
        g_showPlayers = !g_showPlayers;
    }

    // Display players and teams
    if (g_showPlayers) {
        string[] humanPlayers;
        string[] botPlayers;

        for (uint i = 0; i < network.PlayerInfos.Length; i++) {
            auto player = cast<CTrackManiaPlayerInfo>(network.PlayerInfos[i]);

            if (player is null || IsSystemPlayer(player)) {
                // ignored
            } else if (IsBotPlayer(player)) {
                botPlayers.InsertLast(player.Name);
            } else {
                humanPlayers.InsertLast(player.Name);
            }
        }

        string playersText = "Players (" + humanPlayers.Length + "): " + string::Join(humanPlayers, ", ");
        string botsText = botPlayers.Length == 0 ? "" : "Bots (" + botPlayers.Length + "): " + string::Join(botPlayers, ", ");

        UI::TextWrapped(playersText);
        
        if (botsText.Length > 0) {
            UI::TextWrapped(botsText);
        }
    }

    // End window
    UI::End();
}

string GetMapNamesForUI(CTrackManiaNetworkServerInfo@ server) { return GetMapNamesInternal(server, "\\$555 | \\$z"); }
string GetMapNamesForChat(CTrackManiaNetworkServerInfo@ server) { return "$z" + GetMapNamesInternal(server, "$000 | $z"); }
string GetMapNamesForClipboard(CTrackManiaNetworkServerInfo@ server) { return GetMapNamesInternal(server, " | "); }
string GetMapNamesInternal(CTrackManiaNetworkServerInfo@ server, const string &in separator) {
    string[] mapNames;

    for (uint i = 0; i < server.ChallengeNames.Length; i++) {
        mapNames.InsertLast(server.ChallengeNames[i]);
    }

    return string::Join(mapNames, separator);
}

void Notify(const string &in text, int duration) {
    UI::ShowNotification(g_pluginName, text, duration);
}

bool BlueButton(const string &in text) { return UI::Button(text); }
bool GrayButton(const string &in text) { return ColoredButton(text, 0.78f, 0.0f, 0.3f); }
bool GreenButton(const string &in text) { return ColoredButton(text, 0.33f, 0.6f, 0.6f); }
bool ColoredButton(const string &in text, float h, float s, float v)
{
    UI::PushStyleColor(UI::Col::Button, UI::HSV(h, s, v));
    UI::PushStyleColor(UI::Col::ButtonHovered, UI::HSV(h, s + 0.1f, v + 0.1f));
    UI::PushStyleColor(UI::Col::ButtonActive, UI::HSV(h, s + 0.2f, v + 0.2f));
    auto clicked = UI::Button(text);
    UI::PopStyleColor(3);
    return clicked;
}

bool IsRoyalServer(CTrackManiaNetworkServerInfo@ server) {
    return server.ServerLogin != ""
        && server.ModeName == "TM_Royal_Online"
        && server.ChallengeNames.Length > 0;
}

bool IsSystemPlayer(CTrackManiaPlayerInfo@ player) {
    // In normal royal, there's a non-real player named "Match: Official royal - match" that we must ignore
    return player.Name.StartsWith("Match: ");
}

bool IsBotPlayer(CTrackManiaPlayerInfo@ player) {
    // Example of a bot full login or idname: "*fakeplayer4*"
    return player.Login.StartsWith("*fakeplayer") || player.IdName.StartsWith("*fakeplayer");
}