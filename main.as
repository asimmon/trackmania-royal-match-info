// Highly inspired from the plugin "Royal Match Monitor" made by "jeFFeSS"
// https://openplanet.dev/plugin/royalmatchmonitor

// Settings
[Setting name="Display map names when match is joined"]
bool setting_CanNotifyMapNames = true;

[Setting name="Display bot names when match is starting"]
bool setting_CanNotifyPlayerNames = true;

// Global state
string g_lastNotifiedMapNamesServerLogin = "";
string g_lastNotifiedPlayerNamesServerLogin = "";
string g_headerName = "\\$fd0" + Icons::Trophy + "\\$z Royal match info";


string BuildMapNamesNotificationText(CGameCtnNetServerInfo@ currentServer) {
    string[] mapNames;

    for (uint i = 0; i < currentServer.ChallengeNames.Length; i++) {
        mapNames.InsertLast(currentServer.ChallengeNames[i]);
    }

    return "Maps: " + string::Join(mapNames, ", ");
}

bool ShouldIgnorePlayer(CTrackManiaPlayerInfo@ player) {
    // In normal royal, there's a non-real player named "Match: Official royal - match" that we must ignore
    return player is null || player.Name.StartsWith("Match: ");
}

bool IsBotPlayer(CTrackManiaPlayerInfo@ player) {
    // Example of a bot full login or idname: "*fakeplayer4*"
    return player.Login.StartsWith("*fakeplayer") || player.IdName.StartsWith("*fakeplayer");
}

string BuildPlayerNamesNotificationText() {
    auto network = cast<CGameCtnNetwork>(GetApp().Network);
    string[] botPlayers;
    string[] realPlayers;

    for (uint i = 0; i < network.PlayerInfos.Length; i++) {
        auto player = cast<CTrackManiaPlayerInfo>(network.PlayerInfos[i]);
        
        if (!ShouldIgnorePlayer(player)) {
            if (IsBotPlayer(player)) {
                botPlayers.InsertLast(player.Name);
            } else {
                realPlayers.InsertLast(player.Name);
            }
        }
    }

    string botsText = botPlayers.Length == 0 ? "No bots detected" : "Bots (" + botPlayers.Length + "): " + string::Join(botPlayers, ", ");
    string playersText = "Players (" + realPlayers.Length + "): " + string::Join(realPlayers, ", ");

    return botsText + "\n\n" + playersText;
}

bool IsMatchStarting() {
    auto currentPlayground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if(currentPlayground is null or currentPlayground.GameTerminals.Length < 1 || currentPlayground.GameTerminals[0].ControlledPlayer is null) {
        return false;
    }

    auto player = cast<CSmPlayer>(currentPlayground.GameTerminals[0].ControlledPlayer);
    if (player is null) {
        return false;
    }

    return true;
}

bool IsMatchStarted() {
    auto currentPlayground = cast<CSmArenaClient>(GetApp().CurrentPlayground);
    if(currentPlayground is null or currentPlayground.GameTerminals.Length < 1 || currentPlayground.GameTerminals[0].ControlledPlayer is null) {
        return false;
    }

    auto player = cast<CSmPlayer>(currentPlayground.GameTerminals[0].ControlledPlayer);
    if (player is null) {
        return false;
    }

    auto scriptAPI = cast<CSmScriptPlayer>(player.ScriptAPI);
    if(scriptAPI is null) {
        return false;
    }

    // -1 while waiting for players to join, >= 0 when match has started
    return scriptAPI.StartTime >= 0;
}

bool IsOnlineRoyalMatch(CGameCtnNetServerInfo@ currentServer) {
    return currentServer.ServerLogin != ""
      && currentServer.ModeName == "TM_Royal_Online"
      && currentServer.ChallengeNames.Length > 0;
}

bool ShouldNotifyMapNames(CGameCtnNetServerInfo@ currentServer) {
    return setting_CanNotifyMapNames
      && IsOnlineRoyalMatch(currentServer)
      && currentServer.ServerLogin != g_lastNotifiedMapNamesServerLogin
      && IsMatchStarting();
}

bool ShouldNotifyPlayerNames(CGameCtnNetServerInfo@ currentServer) {
    return setting_CanNotifyPlayerNames
      && IsOnlineRoyalMatch(currentServer)
      && currentServer.ServerLogin != g_lastNotifiedPlayerNamesServerLogin
      && IsMatchStarted();
}

void Notify(const string &in text, int duration) {
    print(text);
    UI::ShowNotification(g_headerName, text, duration);
}

CGameCtnNetServerInfo@ GetCurrentServer() {
    auto network = cast<CGameCtnNetwork>(GetApp().Network);
    auto appServer = cast<CGameCtnNetServerInfo>(network.ServerInfo);

    CGameCtnNetServerInfo@ currentServer;
    for (uint i = 0; i < network.OnlineServers.Length; i++) {
        CGameCtnNetServerInfo@ serverInfo = cast<CGameCtnNetServerInfo>(network.OnlineServers[i]);
        if (appServer.ServerLogin == serverInfo.ServerLogin) {
            @currentServer = serverInfo;
            break;
        }
    }
    return currentServer;
}

void RenderMenu() {
    if (UI::BeginMenu(g_headerName, NadeoServices::IsAuthenticated("NadeoClubServices"))) {
        auto currentServer = GetCurrentServer();

        bool areMapNamesAvailable = currentServer !is null && IsOnlineRoyalMatch(currentServer);
        bool arePlayerNamesAvailable = areMapNamesAvailable && IsMatchStarted();

        string gameNotStartedSuffix = " (game not started)";
        string displayMapNamesButtonText = "Display map names" + (areMapNamesAvailable ? "" : gameNotStartedSuffix);
        string displayPlayerNamesButtonText = "Display bot and player names" + (arePlayerNamesAvailable ? "" : gameNotStartedSuffix);

        string copyMapNamesButtonText = "Copy map names to clipboard" + (areMapNamesAvailable ? "" : gameNotStartedSuffix);
        string copyPlayerNamesButtonText = "Copy bot and player names to clipboard" + (arePlayerNamesAvailable ? "" : gameNotStartedSuffix);

        if (UI::MenuItem(displayMapNamesButtonText, "", false, areMapNamesAvailable)) {
            Notify(BuildMapNamesNotificationText(currentServer), 10000);
        }

        if (UI::MenuItem(displayPlayerNamesButtonText, "", false, arePlayerNamesAvailable)) {
            Notify(BuildPlayerNamesNotificationText(), 10000);
        }

        if (UI::MenuItem(copyMapNamesButtonText, "", false, areMapNamesAvailable)) {
            IO::SetClipboard(BuildMapNamesNotificationText(currentServer));
            Notify("Map names copied to clipboard", 5000);
        }

        if (UI::MenuItem(copyPlayerNamesButtonText, "", false, arePlayerNamesAvailable)) {
            IO::SetClipboard(BuildPlayerNamesNotificationText());
            Notify("Player names copied to clipboard", 5000);
        }

		UI::EndMenu();
    }
}

void Main() {
    NadeoServices::AddAudience("NadeoClubServices");
    while (!NadeoServices::IsAuthenticated("NadeoClubServices")) {
        yield();
    }

    while (true) {
        yield();

        auto currentServer = GetCurrentServer();

        if (currentServer !is null) {
            if (ShouldNotifyMapNames(currentServer)) {
                g_lastNotifiedMapNamesServerLogin = currentServer.ServerLogin;
                Notify(BuildMapNamesNotificationText(currentServer), 20000);
            }

            if (ShouldNotifyPlayerNames(currentServer)) {
                g_lastNotifiedPlayerNamesServerLogin = currentServer.ServerLogin;
                Notify(BuildPlayerNamesNotificationText(), 10000);
            }
        }

        sleep(1000);
    }
}