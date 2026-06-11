#include <std_include.hpp>

#include "game.hpp"

#include <utils/flags.hpp>
#include <utils/finally.hpp>

namespace game {
namespace {
const utils::nt::library &get_host_library() {
  static const auto host_library = [] {
    utils::nt::library host{};
    if (!host || host == utils::nt::library::get_by_address(get_base)) {
      throw std::runtime_error("Invalid host application - Make sure you place "
                               "swiflyboiii.exe next to BlackOps3.exe!");
    }

    return host;
  }();

  return host_library;
}

void seed_appdata_from_local_data_folder(const std::filesystem::path &appdata) {
  std::error_code ec{};

  const auto source_data = std::filesystem::current_path() / "data";
  const auto target_data = appdata / "data";

  if (!std::filesystem::exists(source_data, ec) ||
      !std::filesystem::is_directory(source_data, ec)) {
    return;
  }

  std::filesystem::create_directories(appdata, ec);
  ec.clear();

  std::filesystem::copy(source_data, target_data,
                        std::filesystem::copy_options::recursive |
                            std::filesystem::copy_options::overwrite_existing,
                        ec);
}
} // namespace

size_t get_base() {
  static const auto base =
      reinterpret_cast<size_t>(get_host_library().get_ptr());
  return base;
}

bool is_server() {
  static const auto server =
      get_host_library().get_optional_header()->CheckSum == 0x14C28B4;
  return server;
}

bool is_client() {
  static const auto server =
      get_host_library().get_optional_header()->CheckSum == 0x888C368;
  return server;
}

bool is_legacy_client() {
  static const auto server =
      get_host_library().get_optional_header()->CheckSum == 0x8880704;
  return server;
}

bool is_headless() {
  static const auto headless = utils::flags::has_flag("headless");
  return headless;
}

void show_error(const std::string &text, const std::string &title) {
  if (is_headless()) {
    puts(text.data());
  } else {
    MessageBoxA(nullptr, text.data(), title.data(),
                MB_ICONERROR | MB_SETFOREGROUND | MB_TOPMOST);
  }
}

std::filesystem::path get_appdata_path() {
  static const auto appdata_path = []() -> std::filesystem::path {
    PWSTR path = nullptr;
    if (FAILED(
            SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path))) {
      throw std::runtime_error("Failed to read APPDATA path!");
    }

    auto _ = utils::finally([&path] { CoTaskMemFree(path); });

    // Keep using the BOIII cache folder so existing first-launch data is found.
    const auto result = std::filesystem::path(path) / L"boiii";
    seed_appdata_from_local_data_folder(result);
    return result;
  }();

  return appdata_path;
}

std::filesystem::path get_game_path() {
  return std::filesystem::current_path();
}
} // namespace game
