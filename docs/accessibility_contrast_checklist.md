# Accessibility Contrast Checklist

Use this checklist to spot-check WCAG AA contrast for core text and interactive states when palettes change.

## Text on light surfaces
- AppColors.textPrimary on AppColors.surface and AppColors.surfaceLight.
- AppColors.textSecondary on AppColors.surface and AppColors.surfaceLight.
- AppColors.error, AppColors.success on AppColors.surface and AppColors.surfaceLight.
- AppTypography.thoughtLog on AppColors.thoughtLogBackgroundLight.

## Text on dark surfaces
- AppColors.darkTextPrimary on AppColors.darkBackground and AppColors.darkSurface.
- AppColors.darkTextSecondary on AppColors.darkBackground and AppColors.darkSurface.
- AppTypography.thoughtLog on AppColors.thoughtLogBackgroundDark.

## Interactive elements
- NavigationBar icons and labels against the scaffold background.
- FilledButton text against primary background.
- Verification badge text against badge background fill.
- Map pins against the map surface.

## Notes
- If a pair is below 4.5:1 for normal text, switch to a higher-contrast token from AppColors or Theme.of(context).colorScheme.*.
- For large text (>= 18pt regular or 14pt bold), 3:1 is acceptable.
