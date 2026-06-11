#include <std_include.hpp>

#include "updater.hpp"

namespace updater {
void run(const std::filesystem::path & /*base*/) {
  // Swifly does not use the upstream BOIII/Ezz updater. Keep this as a no-op so
  // no caller can reach file_updater or the old r2.ezz.lol update channel.
}
} // namespace updater
