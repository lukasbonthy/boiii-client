#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include <utils/nt.hpp>

namespace {
std::optional<std::filesystem::path> find_bundled_d3d11() {
  const auto self = utils::nt::library::get_by_address(find_bundled_d3d11);
  const auto self_dir = self.get_path().parent_path();

  const std::filesystem::path candidates[] = {
      self_dir / "swifly_d3d11.dll",
      self_dir / "data" / "d3d11.dll",
      std::filesystem::current_path() / "swifly_d3d11.dll",
      std::filesystem::current_path() / "data" / "d3d11.dll",
  };

  std::error_code ec{};
  for (const auto &candidate : candidates) {
    ec.clear();
    if (std::filesystem::is_regular_file(candidate, ec)) {
      return candidate;
    }
  }

  return std::nullopt;
}

void install_bundled_d3d11() {
  const auto source = find_bundled_d3d11();
  if (!source) {
    return;
  }

  const auto target = std::filesystem::current_path() / "d3d11.dll";
  std::error_code ec{};

  const auto source_abs = std::filesystem::absolute(*source, ec);
  if (ec) {
    throw std::runtime_error("Failed to resolve bundled d3d11.dll path: " +
                             ec.message());
  }

  const auto target_abs = std::filesystem::absolute(target, ec);
  if (ec) {
    throw std::runtime_error("Failed to resolve target d3d11.dll path: " +
                             ec.message());
  }

  if (source_abs == target_abs) {
    return;
  }

  std::filesystem::copy_file(source_abs, target_abs,
                             std::filesystem::copy_options::overwrite_existing,
                             ec);
  if (ec) {
    throw std::runtime_error("Failed to replace d3d11.dll: " + ec.message());
  }
}
} // namespace

namespace d3d11_installer {
struct component final : client_component {
  void post_load() override { install_bundled_d3d11(); }
};
} // namespace d3d11_installer

REGISTER_COMPONENT(d3d11_installer::component)
