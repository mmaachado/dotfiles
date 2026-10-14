The core idea is to keep KDE Plasma as the desktop environment and use Quickshell as a custom visual and interaction layer. Retaining KDE's mature infrastructure while gaining the flexibility to build a modern, cohesive interface inspired by Hyprland, Niri, and bespoke Wayland desktops.

## key benefits
1. KDE's stability and mature infrastructure: Keep Plasma's session management, display configuration, power management, notifications, device integration, and settings.
2. Complete freedom over the visual experience: Quickshell allow to build custom panels, docks, application launchers, widgets, status display, and notification interfaces using Qt Quick and QML.
3. Separation of responsabilities: KDE handles the underlying desktop, Quickshell handles the interface we want to customize.
4. Modern interactions and animations: Design fluid workspaces indicators, animated docks, dynamic menus, blurred surfaces, custom transitions, and contextual widgets.

## design rules
- Subtle translucency over heavy blur everywhere;
- Use animation to communicate state changes, not merely for decoration;
- Respect reduced-motion preferences where practical;
- Support keyboard navigation throughout the shell;
- Make the interface usable without animations or transparency;
- Avoid persistent widgets that consume space without providing useful information;
