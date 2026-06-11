#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "command.hpp"
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

void join_swifly_server() {
  game::Com_Printf(0, 0, "[Swifly] Fetching server list...\n");

  const auto address = fetch_swifly_join_address();
  if (!address) {
    game::Com_Printf(0, 0,
                     "[Swifly] No available Swifly servers were found.\n");
    return;
  }

  game::Com_Printf(0, 0, "[Swifly] Joining %s...\n", address->data());
  const auto command = "connect " + *address + "\n";
  game::Cbuf_AddText(0, command.data());
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
