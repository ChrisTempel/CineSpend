# Contributing to CineSpend

Thank you for your interest in contributing to CineSpend! This project was created to provide independent filmmakers with a free, powerful alternative to expensive budgeting software.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs. actual behavior
- Screenshots if applicable
- Your macOS version and Xcode version

### Suggesting Features

Feature suggestions are welcome! Please open an issue with:
- A clear description of the feature
- Why it would be useful for filmmakers
- How it might work (if you have ideas)

### Code Contributions

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
   - Follow Swift and SwiftUI best practices
   - Keep the UI clean and intuitive
   - Test thoroughly on macOS 12.0+
4. **Commit your changes** (`git commit -m 'Add amazing feature'`)
5. **Push to your branch** (`git push origin feature/amazing-feature`)
6. **Open a Pull Request**

### Development Setup

1. Clone the repository
2. Open Xcode
3. Create a new macOS App project
4. Add all `.swift` files from the repository
5. Add `CineSpend.entitlements` and configure sandbox permissions
6. Build and run (⌘R)

See README.md for detailed setup instructions.

## Code Style Guidelines

- Use clear, descriptive variable names
- Follow SwiftUI conventions
- Add comments for complex logic
- Keep functions focused and single-purpose
- Maintain the professional, clean UI aesthetic

## Areas That Need Help

- [ ] Import/Export from CSV/Excel
- [ ] Budget templates (Documentary, Narrative, etc.)
- [ ] Multi-currency support
- [ ] Fringes and payroll tax calculations
- [ ] Above-the-line vs. below-the-line breakdowns
- [ ] Budget comparison tools
- [ ] Performance optimizations for large budgets

## Testing

Before submitting a PR, please test:
- Creating new projects
- Saving and loading projects
- PDF export
- Unit calculator functionality
- Dark/Light mode switching
- All keyboard shortcuts

## Questions?

Feel free to open an issue with the "question" label if you need clarification on anything.

## Code of Conduct

Be respectful, constructive, and supportive. We're all here to help independent filmmakers create better budgets.

---

Thank you for helping make CineSpend better for the filmmaking community! 🎬
