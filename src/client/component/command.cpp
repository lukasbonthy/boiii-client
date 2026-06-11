#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "command.hpp"
#include "network.hpp"
#include <utils/hook.hpp>
#include <utils/string.hpp>
#include <utils/memory.hpp>
#include <utils/http.hpp>

#include <game/game.hpp>
#include <steam/steam.hpp>

#include <rapidjson/document.h>

namespace command {
namespace {
constexpr auto SWIFLY_SERVERS_API = "https://swifly-servers.onrender.com/api/servers";

struct swifly_server_target {
  std::string address{};
  std::string map{"mp_havoc"};
  std::string gametype{"tdm"};
  int max_players{18};
};

std::unordered_map<std::string, command_param_function> &get_command_map() {
  static std::unordered_map<std::string, command_param_function> command_map{};
  return command_map;
}

std::unordered_map<std::string, sv_command_param_function> &
get_sv_command_map() {
  static std::unordered_map<std::string, sv_command_param_function>
      command_map{};
  return command_map;
}

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

std::optional<swifly_server_target> fetch_swifly_server_target() {
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

    swifly_server_target target{};
    target.address = get_string_member(server, "connectAddr");
    const auto host = get_string_member(server, "address");
    const auto port = get_int_member(server, "port", 0);
    const auto players = get_int_member(server, "players", 0);
    target.max_players = get_int_member(server, "maxPlayers", 18);
    const auto passworded = get_bool_member(server, "passworded", false);

    const auto map = get_string_member(server, "map");
    if (!map.empty()) {
      target.map = map;
    }

    const auto gametype = get_string_member(server, "gametype");
    if (!gametype.empty()) {
      target.gametype = gametype;
    }

    if (target.address.empty() && !host.empty() && port > 0) {
      target.address = host + ":" + std::to_string(port);
    }

    if (target.address.empty() || passworded || players >= target.max_players) {
      continue;
    }

    if (!is_safe_join_address(target.address)) {
      continue;
    }

    return target;
  }

  return std::nullopt;
}

void join_swifly_server() {
  game::Com_Printf(0, 0, "[Swifly] Fetching server list...\n");

  const auto target = fetch_swifly_server_target();
  if (!target) {
    game::Com_Printf(0, 0,
                     "[Swifly] No available Swifly servers were found.\n");
    return;
  }

  auto address = network::address_from_string(target->address);
  if (address.type == game::NA_BAD) {
    game::Com_Printf(0, 0, "[Swifly] Bad server address: %s\n",
                     target->address.data());
    return;
  }

  game::Com_Printf(0, 0, "[Swifly] Joining %s...\n",
                   target->address.data());

  game::Com_SessionMode_SetNetworkMode(game::MODE_NETWORK_ONLINE);
  game::Com_SessionMode_SetMode(game::MODE_MULTIPLAYER);
  game::Com_SessionMode_SetGameMode(game::MODE_GAME_MATCHMAKING_MANUAL);
  game::Com_GametypeSettings_SetGametype(target->gametype.data(), true);

  game::XSESSION_INFO session_info{};
  game::CL_ConnectFromLobby(game::CONTROLLER_INDEX_FIRST, &session_info,
                            &address, target->max_players, 0,
                            target->map.data(), target->gametype.data(), "");
}

void execute_custom_command() {
  const params params{};
  const auto command = utils::string::to_lower(params[0]);

  auto &map = get_command_map();
  const auto entry = map.find(command);
  if (entry != map.end()) {
    entry->second(params);
  }
}

void execute_custom_sv_command() {
  const params_sv params{};
  const auto command = utils::string::to_lower(params[0]);

  auto &map = get_sv_command_map();
  const auto entry = map.find(command);
  if (entry != map.end()) {
    entry->second(params);
  }
}

game::CmdArgs *get_cmd_args() { return game::Sys_GetTLS()->cmdArgs; }

void update_whitelist_stub() {
  game::cmd_function_s *current_function = game::cmd_functions;
  while (current_function) {
    current_function->autoComplete = 1;
    current_function = current_function->next;
  }
}
} // namespace

params::params() : nesting_(get_cmd_args()->nesting) {
  assert(this->nesting_ < game::CMD_MAX_NESTING);
}

params::params(const std::string &text) : needs_end_(true) {
  auto *cmd_args = get_cmd_args();
  game::Cmd_TokenizeStringKernel(0, game::CONTROLLER_INDEX_FIRST, text.data(),
                                 512 - cmd_args->totalUsedArgvPool, false,
                                 cmd_args);

  this->nesting_ = cmd_args->nesting;
}

params::~params() {
  if (this->needs_end_) {
    game::Cmd_EndTokenizedString();
  }
}

int params::size() const { return get_cmd_args()->argc[this->nesting_]; }

params_sv::params_sv() : nesting_(game::sv_cmd_args->nesting) {
  assert(this->nesting_ < game::CMD_MAX_NESTING);
}

params_sv::params_sv(const std::string &text) : needs_end_(true) {
  game::SV_Cmd_TokenizeString(text.data());
  this->nesting_ = game::sv_cmd_args->nesting;
}

params_sv::~params_sv() {
  if (this->needs_end_) {
    game::SV_Cmd_EndTokenizedString();
  }
}

int params_sv::size() const { return game::sv_cmd_args->argc[this->nesting_]; }

const char *params_sv::get(const int index) const {
  if (index >= this->size()) {
    return "";
  }

  return game::sv_cmd_args->argv[this->nesting_][index];
}

std::string params_sv::join(const int index) const {
  std::string result;

  for (auto i = index; i < this->size(); ++i) {
    if (i > index)
      result.append(" ");
    result.append(this->get(i));
  }

  return result;
}

const char *params::get(const int index) const {
  if (index >= this->size()) {
    return "";
  }

  return get_cmd_args()->argv[this->nesting_][index];
}

std::string params::join(const int index) const {
  std::string result = {};

  for (auto i = index; i < this->size(); i++) {
    if (i > index)
      result.append(" ");
    result.append(this->get(i));
  }
  return result;
}

void add(const std::string &command, command_function function) {
  add(command, [f = std::move(function)](const params &) { f(); });
}

void add(const std::string &command, command_param_function function) {
  auto lower_command = utils::string::to_lower(command);

  auto &map = get_command_map();
  const auto is_registered = map.contains(lower_command);

  map[std::move(lower_command)] = std::move(function);

  if (is_registered) {
    return;
  }

  auto &allocator = *utils::memory::get_allocator();
  auto *cmd_function = allocator.allocate<game::cmd_function_s>();
  const auto *cmd_string = allocator.duplicate_string(command);

  game::Cmd_AddCommandInternal(cmd_string, execute_custom_command,
                               cmd_function);
  cmd_function->autoComplete = 1;
}

void add_sv(const std::string &command, sv_command_param_function function) {
  auto lower_command = utils::string::to_lower(command);

  auto &map = get_sv_command_map();
  const auto is_registered = map.contains(lower_command);

  map[std::move(lower_command)] = std::move(function);

  if (is_registered) {
    return;
  }

  auto &allocator = *utils::memory::get_allocator();
  const auto *cmd_string = allocator.duplicate_string(command);

  game::Cmd_AddCommandInternal(cmd_string, game::Cbuf_AddServerText_f,
                               allocator.allocate<game::cmd_function_s>());
  game::Cmd_AddServerCommandInternal(
      cmd_string, execute_custom_sv_command,
      allocator.allocate<game::cmd_function_s>());
}

struct component final : generic_component {
  void post_unpack() override {
    // Disable whitelist
    utils::hook::jump(game::select(0x1420EE860, 0x1404F9CD0),
                      update_whitelist_stub);

    command::add("join_swifly_server", join_swifly_server);
  }
};
} // namespace command

REGISTER_COMPONENT(command::component)
