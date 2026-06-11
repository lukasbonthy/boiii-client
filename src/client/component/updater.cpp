#include <std_include.hpp>
#include "loader/component_loader.hpp"
#include "updater.hpp"
#include "game/game.hpp"

#include <utils/flags.hpp>
#include <utils/progress_ui.hpp>
#include <updater/updater.hpp>

namespace updater {
void update() {
  // The upstream updater pulls from the EZZ/BOIII update server and can replace
  // this branded Swifly build with the original BOIII client. Keep it disabled
  // unless/until Swifly has its own update manifest and release channel.
  return;
}

class component final : public generic_component {
public:
  component() = default;

  void pre_destroy() override { join(); }

  void post_unpack() override { join(); }

  component_priority priority() const override {
    return component_priority::updater;
  }

private:
  std::thread update_thread_{};

  void join() {
    if (this->update_thread_.joinable()) {
      this->update_thread_.join();
    }
  }
};
} // namespace updater

REGISTER_COMPONENT(updater::component)
