# LMIP Naming Convention Mapping

**Purpose**: Quick reference for old (hospitality-specific) to new (sector-agnostic) naming conventions  
**Status**: ✅ Complete  
**Last Updated**: June 8, 2026

---

## Quick Reference Table

| Asset Type | Old Name (Hospitality) | New Name (Multi-Sector) | Status |
|------------|------------------------|-------------------------|--------|
| **Notebook** | `gold_hospitality_companies.ipynb` | `gold_company_activity.ipynb` | ✅ Renamed |
| **Notebook** | `gold_hospitality_hiring.ipynb` | `gold_hiring_activity.ipynb` | ✅ Renamed |
| **Notebook** | `gold_hospitality_skills.ipynb` | `gold_skill_demand_by_sector.ipynb` | ✅ Renamed |
| **Contract** | `gold_hospitality_companies.yaml` | `gold_company_activity.yaml` | ✅ Renamed |
| **Contract** | `gold_hospitality_hiring.yaml` | `gold_hiring_activity.yaml` | ✅ Renamed |
| **Contract** | `gold_hospitality_skills.yaml` | `gold_skill_demand_by_sector.yaml` | ✅ Renamed |
| **DDL** | `gold_gold_hospitality_companies.sql` | `gold_gold_company_activity.sql` | ✅ Renamed |
| **DDL** | `gold_gold_hospitality_hiring.sql` | `gold_gold_hiring_activity.sql` | ✅ Renamed |
| **DDL** | `gold_gold_hospitality_skills.sql` | `gold_gold_skill_demand_by_sector.sql` | ✅ Renamed |
| **Table** | `workspace.gold.gold_hospitality_companies` | `workspace.gold.gold_company_activity` | ✅ Created |
| **Table** | `workspace.gold.gold_hospitality_hiring` | `workspace.gold.gold_hiring_activity` | ✅ Created |
| **Table** | `workspace.gold.gold_hospitality_skills` | `workspace.gold.gold_skill_demand_by_sector` | ✅ Created |
| **Workflow Task** | `Gold_Hospitality_Companies` | `Gold_Company_Activity` | ✅ Updated |
| **Workflow Task** | `Gold_Hospitality_Hiring` | `Gold_Hiring_Activity` | ✅ Updated |
| **Workflow Task** | `Gold_Hospitality_Skills` | `Gold_Skill_Demand_By_Sector` | ✅ Updated |

---

## Backward Compatibility Views

Old table names still work via compatibility views that filter to hospitality sector:

| Old Name (Still Works) | Implementation | Filter Logic |
|------------------------|----------------|--------------|
| `workspace.gold.gold_hospitality_companies` | VIEW -> `gold_company_activity` | `WHERE sector_family = 'Hospitality'` |
| `workspace.gold.gold_hospitality_hiring` | VIEW -> `gold_hiring_activity` | `WHERE sector_family = 'Hospitality'` |
| `workspace.gold.gold_hospitality_skills` | VIEW -> `gold_skill_demand_by_sector` | `WHERE sector_family = 'Hospitality'` |

**Note**: Existing queries using old table names continue to work without modification.

---

## Naming Conventions

### General Pattern

**Old Pattern**: `gold_hospitality_<entity>`  
**New Pattern**: `gold_<entity>_activity` or `gold_<entity>_by_sector`

### Rationale
- **Remove "hospitality"**: Makes tables sector-agnostic
- **Add context**: "_activity", "_by_sector" clarifies table purpose
- **Consistency**: All gold tables follow similar naming pattern

---

## File Locations

### Notebooks
```
/Workspace/Users/{user}/LMIP/notebooks/gold/
├── gold_company_activity.ipynb         # (was: gold_hospitality_companies)
├── gold_hiring_activity.ipynb          # (was: gold_hospitality_hiring)
└── gold_skill_demand_by_sector.ipynb   # (was: gold_hospitality_skills)
```

### Contracts
```
/Workspace/Users/{user}/LMIP/contracts/gold/
├── gold_company_activity.yaml
├── gold_hiring_activity.yaml
└── gold_skill_demand_by_sector.yaml
```

### DDL Files
```
/Workspace/Users/{user}/LMIP/sql/ddl/
├── gold_gold_company_activity.sql
├── gold_gold_hiring_activity.sql
└── gold_gold_skill_demand_by_sector.sql
```

### View Definitions
```
/Workspace/Users/{user}/LMIP/sql/views/
├── view_gold_company_activity_hospitality.sql
├── view_gold_hiring_activity_hospitality.sql
└── view_gold_skill_demand_by_sector_hospitality.sql
```

---

## Schema Changes

### Added Column: sector_sk

All new tables include `sector_sk` as the first column.

---

## Usage Examples

### Querying New Tables (All Sectors)

Get company activity across all sectors by joining with dim_sector.

### Querying via Compatibility Views (Hospitality Only)

Old queries still work - automatically filters to hospitality sector.

### Filtering by Sector in New Tables

Explicitly filter by sector_name or sector_family in joins.

---

## Code Reference Patterns

### Importing Tables in Notebooks

**Old Pattern**: Import gold_hospitality_companies  
**New Pattern**: Import gold_company_activity  
**Compatibility**: Use gold_hospitality_companies view for filtered data

---

## Migration Checklist

- Update notebook imports to new table names
- Add `sector_sk` to SELECT statements
- Update JOIN conditions to include `sector_sk`
- Add sector filters where needed
- Update window functions to partition by `sector_sk`
- Update workflow task references
- Update publishing configurations
- Test backward compatibility via views
- Validate data lineage

---

## Common Pitfalls & Solutions

### Missing sector_sk in queries
Always include sector_sk in GROUP BY when aggregating.

### Hardcoded sector filters
Use parameters or compatibility views instead of hardcoded WHERE clauses.

### Window functions without sector_sk
Always partition window functions by sector_sk first.

---

## Support & Documentation

### Additional Resources
- **Migration Plan**: `/LMIP/GENERALIZATION_MIGRATION_PLAN.md`
- **Audit Report**: `/LMIP/GENERALIZATION_AUDIT.md`
- **README**: `/LMIP/README.md`
- **Contract Schemas**: `/LMIP/contracts/gold/`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-06-08 | Initial naming mapping after migration completion |

---

*Document Version: 1.0*  
*Last Updated: June 8, 2026*  
*Status: ✅ COMPLETE*
