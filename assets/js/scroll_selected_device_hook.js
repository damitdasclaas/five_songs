const ScrollSelectedDeviceHook = {
  mounted() { this.scrollToSelected(); },
  updated() { this.scrollToSelected(); },
  scrollToSelected() {
    const id = this.el.dataset?.selectedDeviceId;
    if (!id) return;
    const row = this.el.querySelector(`[data-device-id="${id}"]`);
    if (row) row.scrollIntoView({ block: "nearest", behavior: "instant" });
  }
};

export default ScrollSelectedDeviceHook;
