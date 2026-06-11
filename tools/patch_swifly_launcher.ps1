$ErrorActionPreference = 'Stop'

$serversApi = 'https://swifly-servers.onrender.com/api/servers'

function Write-Utf8NoBom($Path, $Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Resolve-Path $Path), $Content, $utf8NoBom)
}

# Brand and simplify the launcher HTML.
$htmlPath = 'data/launcher/main.html'
if (Test-Path $htmlPath) {
  $html = Get-Content $htmlPath -Raw
  $html = $html.Replace('<title>BOIII</title>', '<title>Swifly BOIII</title>')
  $html = $html.Replace('EZZ BOIII', 'Swifly BOIII')
  $html = $html.Replace('Ezz BOIII', 'Swifly BOIII')
  $html = $html.Replace('<span class="title-white title-big">E</span><span class="title-white">ZZ</span>', '<span class="title-white title-big">S</span><span class="title-white">wifly</span>')
  $html = $html.Replace('<span class="title-orange">BOIII</span>', '<span class="title-orange">BOIII</span>')
  $html = $html.Replace('Call of Duty: Black Ops 3 enhanced with our modifications.', 'Call of Duty: Black Ops 3 enhanced by Swifly BOIII.')
  $html = $html.Replace('Latest (Auto-update)', 'Latest')
  $html = $html.Replace('https://discord.gg/ezz', 'https://discord.gg/swifly')
  $html = $html.Replace('https://ezz.lol', 'https://swifly.gg')

  if ($html -notmatch 'data-option="vanilla"') {
    $marker = '              <div class="launch-option-card" data-option="console"'
    $insert = '              <div class="launch-option-card" data-option="vanilla" title="Enable BOIII Vanilla campaign/speedrun-friendly behavior"><span class="launch-option-dot"></span><span class="launch-option-name">Vanilla Mode</span></div>' + [Environment]::NewLine
    $html = $html.Replace($marker, $insert + $marker)
  }

  $joinButton = '<button type="button" class="btn-play-large" id="playBtn">&#127760; JOIN GAME</button><div id="joinGameStatus" class="join-game-status">Joins the first available Swifly server.</div>'
  $html = [regex]::Replace($html, '<button type="button" class="btn-play-large" id="playBtn">[\s\S]*?</button>(?:\s*<div id="joinGameStatus" class="join-game-status">[\s\S]*?</div>)?', $joinButton, 1)

  Write-Utf8NoBom $htmlPath $html
}

# Add lightweight styling for the Join Game status line.
$cssPath = 'data/launcher/main.css'
if (Test-Path $cssPath) {
  $css = Get-Content $cssPath -Raw
  if ($css -notmatch 'join-game-status') {
    $css += @'

.join-game-status {
  margin-top: 10px;
  color: rgba(255, 255, 255, 0.62);
  font-size: 0.78rem;
  text-align: center;
  min-height: 1rem;
}

.join-game-status.error {
  color: rgba(239, 68, 68, 0.95);
}

.join-game-status.ok {
  color: rgba(34, 197, 94, 0.95);
}
'@
    Write-Utf8NoBom $cssPath $css
  }
}

# Override the Play button behavior in launcher JS after the original handler is registered.
$jsPath = 'data/launcher/main.js'
if (Test-Path $jsPath) {
  $js = Get-Content $jsPath -Raw
  $js = $js.Replace('https://cdn.ezz.lol/boiii/beta/boiii.exe', 'https://swifly-servers.onrender.com/disabled-beta/boiii.exe')
  $js = $js.Replace("name : 'boiii-beta.exe'", "name : 'swifly-beta.exe'")

  if ($js -notmatch 'SWIFLY_SERVERS_API') {
    $joinJs = @"

var SWIFLY_SERVERS_API = '$serversApi';
(function() {
  var btn = document.getElementById('playBtn');
  var status = document.getElementById('joinGameStatus');
  if (!btn)
    return;

  function setJoinStatus(text, cls) {
    if (!status)
      return;
    status.className = 'join-game-status' + (cls ? ' ' + cls : '');
    status.textContent = text || '';
  }

  btn.innerHTML = '&#127760; JOIN GAME';
  btn.title = 'Join the first available Swifly server';
  btn.onclick = function() {
    try {
      var ex = getExternal();
      if (ex && ex.isGameRunning && ex.isGameRunning() === '1') {
        showMessage('Game Running', 'Black Ops III is already running.');
        return;
      }
      if (!ex || !ex.joinSwiflyGame) {
        showMessage('Join Game', 'This Swifly build does not support auto-join yet. Rebuild the client.');
        return;
      }

      btn.disabled = true;
      setJoinStatus('Finding an online Swifly server...', '');

      var result = ex.joinSwiflyGame(window.getPlayerName(), window.getSelectedLaunchOption());
      result = String(result || 'error');

      if (result.indexOf('ok:') === 0) {
        var address = result.substring(3);
        setJoinStatus('Joining ' + address + '...', 'ok');
        return;
      }

      btn.disabled = false;
      if (result === 'game_running') {
        showMessage('Game Running', 'Black Ops III is already running.');
        setJoinStatus('Game is already running.', 'error');
      } else if (result === 'no_servers') {
        showMessage('Join Game', 'No available Swifly servers are online right now.');
        setJoinStatus('No available Swifly servers are online.', 'error');
      } else if (result === 'bad_response') {
        showMessage('Join Game', 'The Swifly server list returned invalid data.');
        setJoinStatus('Invalid server list response.', 'error');
      } else {
        showMessage('Join Game', 'Failed to contact the Swifly server list.');
        setJoinStatus('Could not reach ' + SWIFLY_SERVERS_API, 'error');
      }
    } catch (e) {
      btn.disabled = false;
      setJoinStatus('Join failed: ' + (e.message || e), 'error');
      showMessage('Join Game', 'Join failed: ' + (e.message || e));
    }
  };
})();
"@
    $js = [regex]::Replace($js, '\s*\}\)\(\);\s*$', $joinJs + [Environment]::NewLine + '})();' + [Environment]::NewLine)
    Write-Utf8NoBom $jsPath $js
  }
}

# Add a native C++ callback that fetches the Swifly API and relaunches with +connect.
$cppPath = 'src/client/launcher/launcher.cpp'
if (Test-Path $cppPath) {
  $cpp = Get-Content $cppPath -Raw
  $cpp = $cpp.Replace('html_window window("EZZ BOIII", 1260, 680);', 'html_window window("Swifly BOIII", 1260, 680);')
  $cpp = $cpp.Replace('html_window window("Ezz BOIII", 1260, 680);', 'html_window window("Swifly BOIII", 1260, 680);')

  if ($cpp -notmatch 'SWIFLY_SERVERS_API') {
    $helper = @'
constexpr auto SWIFLY_SERVERS_API = "https://swifly-servers.onrender.com/api/servers";

bool is_safe_join_address(const std::string &address) {
  if (address.empty() || address.size() > 128) {
    return false;
  }

  for (const auto c : address) {
    const auto uc = static_cast<unsigned char>(c);
    if ((uc >= '0' && uc <= '9') || (uc >= 'a' && uc <= 'z') ||
        (uc >= 'A' && uc <= 'Z') || c == '.' || c == ':' || c == '-' ||
        c == '_' || c == '[' || c == ']') {
      continue;
    }

    return false;
  }

  return true;
}

std::string get_string_member(const rapidjson::Value &object, const char *key) {
  const auto member = object.FindMember(key);
  if (member == object.MemberEnd() || !member->value.IsString()) {
    return {};
  }

  return member->value.GetString();
}

int get_int_member(const rapidjson::Value &object, const char *key,
                   const int fallback = 0) {
  const auto member = object.FindMember(key);
  if (member == object.MemberEnd()) {
    return fallback;
  }

  if (member->value.IsInt()) {
    return member->value.GetInt();
  }

  if (member->value.IsUint()) {
    return static_cast<int>(member->value.GetUint());
  }

  if (member->value.IsString()) {
    return std::atoi(member->value.GetString());
  }

  return fallback;
}

bool get_bool_member(const rapidjson::Value &object, const char *key,
                     const bool fallback = false) {
  const auto member = object.FindMember(key);
  if (member == object.MemberEnd()) {
    return fallback;
  }

  if (member->value.IsBool()) {
    return member->value.GetBool();
  }

  if (member->value.IsString()) {
    const auto value = utils::string::to_lower(member->value.GetString());
    return value == "1" || value == "true" || value == "yes";
  }

  return fallback;
}

std::optional<std::string> fetch_swifly_join_address() {
  const auto data = utils::http::get_data(
      SWIFLY_SERVERS_API,
      { {"accept", "application/json"}, {"cache-control", "no-cache"} }, {}, 1);
  if (!data || data->empty()) {
    return std::nullopt;
  }

  rapidjson::Document doc;
  if (doc.Parse(data->c_str()).HasParseError() || !doc.IsArray()) {
    return std::nullopt;
  }

  for (const auto &server : doc.GetArray()) {
    if (!server.IsObject()) {
      continue;
    }

    auto address = get_string_member(server, "connectAddr");
    const auto host = get_string_member(server, "address");
    const auto port = get_int_member(server, "port", 0);
    const auto players = get_int_member(server, "players", 0);
    const auto max_players = get_int_member(server, "maxPlayers", 1);
    const auto passworded = get_bool_member(server, "passworded", false);

    if (address.empty() && !host.empty() && port > 0) {
      address = host + ":" + std::to_string(port);
    }

    if (address.empty() || passworded || players >= max_players) {
      continue;
    }

    if (!is_safe_join_address(address)) {
      continue;
    }

    return address;
  }

  return std::nullopt;
}

void relaunch_and_connect(const std::string &address,
                          const std::vector<std::string> &options) {
  const auto self = utils::nt::library::get_by_address(relaunch_and_connect);
  const auto exe_path = self.get_path().generic_string();

  STARTUPINFOA startup_info;
  PROCESS_INFORMATION process_info;
  ZeroMemory(&startup_info, sizeof(startup_info));
  ZeroMemory(&process_info, sizeof(process_info));
  startup_info.cb = sizeof(startup_info);

  char current_dir[MAX_PATH];
  GetCurrentDirectoryA(sizeof(current_dir), current_dir);

  std::string command_line = "\"" + exe_path + "\" \"-launch\"";
  for (const auto &raw : options) {
    auto token = normalize_option_token(raw);
    if (!token.empty()) {
      command_line += " \"-" + token + "\"";
    }
  }

  command_line += " \"+connect\" \"" + address + "\"";

  if (CreateProcessA(exe_path.data(), command_line.data(), nullptr, nullptr,
                     false, CREATE_NEW_CONSOLE, nullptr, current_dir,
                     &startup_info, &process_info)) {
    if (process_info.hThread && process_info.hThread != INVALID_HANDLE_VALUE) {
      CloseHandle(process_info.hThread);
    }
    if (process_info.hProcess && process_info.hProcess != INVALID_HANDLE_VALUE) {
      CloseHandle(process_info.hProcess);
    }
  }
}

'@
    $cpp = $cpp.Replace("} // namespace`r`n`r`nbool run()", $helper + "} // namespace`r`n`r`nbool run()")
    $cpp = $cpp.Replace("} // namespace`n`nbool run()", $helper + "} // namespace`n`nbool run()")
  }

  if ($cpp -notmatch 'joinSwiflyGame') {
    $callback = @'
  window.get_html_frame()->register_callback(
      "joinSwiflyGame",
      [&](const std::vector<html_argument> &params) -> CComVariant {
        if (is_game_process_running()) {
          return CComVariant("game_running");
        }

        std::string new_name{};
        if (!params.empty() && params[0].is_string()) {
          new_name = sanitize_player_name(params[0].get_string());
          utils::string::trim(new_name);
        }

        if (new_name.empty()) {
          new_name = sanitize_player_name(utils::nt::get_user_name());
          if (new_name.empty()) {
            new_name = "Unknown Soldier";
          }
        }

        if (new_name.size() > 16) {
          new_name.resize(16);
        }
        utils::properties::store("playerName", new_name);

        std::string option_list{};
        if (params.size() >= 2 && params[1].is_string()) {
          option_list = params[1].get_string();
          utils::string::trim(option_list);
        }
        utils::properties::store("launchOptions", option_list);

        std::vector<std::string> opts;
        if (!option_list.empty()) {
          for (auto &part : utils::string::split(option_list, ' ')) {
            auto token = normalize_option_token(std::move(part));
            if (!token.empty()) {
              opts.emplace_back(std::move(token));
            }
          }
        }

        const auto address = fetch_swifly_join_address();
        if (!address) {
          return CComVariant("no_servers");
        }

        relaunch_and_connect(*address, opts);
        return CComVariant(("ok:" + *address).c_str());
      });

'@
    $cpp = $cpp.Replace("  window.get_html_frame()->register_callback(`r`n      \"launchGame\",", $callback + "  window.get_html_frame()->register_callback(`r`n      \"launchGame\",")
    $cpp = $cpp.Replace("  window.get_html_frame()->register_callback(`n      \"launchGame\",", $callback + "  window.get_html_frame()->register_callback(`n      \"launchGame\",")
  }

  Write-Utf8NoBom $cppPath $cpp
}
