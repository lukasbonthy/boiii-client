#include <std_include.hpp>
#include "updater.hpp"
#include "game/game.hpp"

#include <updater/updater.hpp>

namespace updater {
void update() {
  run(game::get_appdata_path());
}
} // namespace updater
