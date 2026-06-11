#include <std_include.hpp>

#include "updater.hpp"

namespace updater {
void run(const std::filesystem::path & /*base*/) {
  // Disabled for Swifly: the upstream implementation downloads the original
  // BOIII manifest/binary from the EZZ update server and can replace this build.
}
} // namespace updater
