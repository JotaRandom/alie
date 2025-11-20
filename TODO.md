# ALIE - Future Enhancements & TODO List

## 🚀 **High Priority Features**

### 0. **Critical Boot Configuration** ✅ COMPLETED [Manual and semi-manual options need testing]
- [x] **Initramfs Modules**: Automatic addition of filesystem modules to mkinitcpio.conf/dracut.conf
- [x] **Swap Resume**: Automatic configuration of resume=UUID parameter for hibernation
- [x] **Btrfs Subvolumes**: Automatic configuration of rootflags=subvol=@ for Btrfs subvolumes
- [x] **Boot Parameter Management**: Safe updating of GRUB_CMDLINE_LINUX_DEFAULT with proper backups
- [x] **Initramfs Regeneration**: Automatic regeneration of initramfs after configuration changes
- [ ] **Selección de Initcpio**: Elegir entre mkinitcpio, booster y dracut, colocándolo junto a base (quedando "init base") durante la primera instalación, o sino base por defecto tomará mkinitcpio.
- [x] **Kernel selection**: Allow multiple kernel options (linux, linux-lts, linux-zen, linux-hardened)
- [x] **Bootloader Flexibility**: Support for GRUB, systemd-boot, and Limine with automatic configurations
- [x] **Initramfs Configuration**: Automatic mkinitcpio/dracut configuration with filesystem modules
- [x] **Boot Parameters**: Automatic GRUB configuration with resume= and subvol= parameters
- [ ] **Syslinux Support**: Add Syslinux as an additional bootloader option
- [ ] **LUKS Encryption**: Full disk encryption with LUKS2 for security
- [ ] **LVM Support**: Logical Volume Management for flexible storage
- [ ] **ZFS Support**: Basic ZFS setup with encryption and snapshots
- [ ] **Additional Filesystems**: F2FS and NILFS2 support for specific use cases

### 2. **Partitioning Enhancements**
- [x] **Robust Unmounting**: Enhanced partition cleanup with multiple unmount attempts and process management (COMPLETED v2.0)
- [ ] **RAID Configuration**: Software RAID setup (RAID 1, 5, 10)
- [ ] **Advanced Btrfs Features**: More subvolume options and configurations
- [ ] **Partition Recovery Tools**: Basic tools to help recover accidentally deleted partitions

## 🔧 **Technical Improvements**

### 3. **Code Quality & Testing**
- [ ] **Unit Tests**: Basic test suite for core functions
- [ ] **Integration Tests**: Automated installation testing in VMs
- [ ] **CI/CD Pipeline**: GitHub Actions for basic testing
- [ ] **Shellcheck Compliance**: Maintain 100% shellcheck compliance

### 4. **Performance Optimizations**
- [ ] **Parallel Package Downloads**: Concurrent package downloads during installation
- [ ] **Package Caching**: Cache downloaded packages between runs
- [ ] **Memory Optimization**: Reduce memory usage for systems with limited RAM

## 🎨 **User Experience Improvements**

### 5. **Interface & Usability**
- [ ] **TUI Interface**: Text-based user interface using dialog or similar
- [ ] **Progress Indicators**: Better progress display for long operations
- [ ] **Configuration Validation**: Pre-flight checks before installation
- [ ] **Error Recovery**: Better error handling and recovery options

### 6. **Localization**
- [ ] **Spanish Translation**: Complete Spanish localization
- [ ] **Additional Languages**: French, German, Portuguese support

## 📦 **Package Management**

### 7. **Package Ecosystem**
- [ ] **AUR Integration**: Enhanced AUR package support and security
- [ ] **Custom Repositories**: Support for additional/custom package repositories
- [ ] **Package Groups**: Pre-defined package collections for common setups

### 8. **Software Selection**
- [ ] **Desktop Environment Options**: Better DE selection with package recommendations
- [ ] **Development Tools**: Enhanced developer tool installation
- [ ] **Gaming Setup**: Basic gaming-related package installation

## 🖥️ **Hardware Support**

### 9. **Device Drivers**
- [ ] **GPU Driver Detection**: Automated NVIDIA/AMD driver installation
- [ ] **WiFi/BT Firmware**: Enhanced wireless hardware support
- [ ] **Printer Setup**: Basic CUPS configuration

## 🌐 **Network & System Configuration**

### 10. **Network Setup**
- [ ] **Advanced Network Config**: Static IP, DNS, proxy settings
- [ ] **Firewall Setup**: Basic UFW configuration
- [ ] **SSH Configuration**: Automated SSH server setup with security hardening

### 11. **System Services**
- [ ] **Time Synchronization**: NTP/chrony configuration
- [ ] **Logging Setup**: Basic system logging configuration
- [ ] **Backup Integration**: Timeshift or similar backup tool setup

## 📚 **Documentation & Maintenance**

### 12. **Documentation**
- [ ] **Installation Guide**: Step-by-step installation documentation
- [ ] **Troubleshooting Guide**: Common issues and solutions
- [ ] **Configuration Examples**: Sample configuration files and use cases

### 13. **Maintenance Tools**
- [ ] **Update Automation**: Basic unattended update setup
- [ ] **System Monitoring**: Basic monitoring tools installation
- [ ] **Recovery Options**: Better system recovery and repair tools

---

## 📊 **Implementation Priority Matrix**

| Priority | Category | Estimated Effort | Impact |
|----------|----------|------------------|---------|
| 🔥 Critical | Core Installation | Medium | High |
| ⚡ High | User Experience | Medium-High | High |
| 🔄 Medium | Advanced Features | High | Medium |
| 🌱 Low | Nice-to-haves | High | Low |

## 🤝 **Contributing**

Want to contribute? Check the [Contributing Guide](CONTRIBUTING.md) and pick an item from this TODO list!

**Legend:**
- 🔥 Critical: Core installation functionality and stability
- ⚡ High: Important user-facing features
- 🔄 Medium: Quality of life improvements
- 🌱 Low: Nice-to-have features

---

*Last updated: November 2025 (Initcpio selection and robust partitioning improvements)*</content>
<parameter name="filePath">c:\Users\Usuario\source\repos\ALIE\TODO.md