#include <std_include.hpp>
#include "updater.hpp"

namespace updater {
void update() {
  // Swifly does not use the upstream BOIII updater. This file intentionally
  // registers no component so the EZZ/BOIII update path cannot run at startup.
}
} // namespace updater
