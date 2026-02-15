import json

with open('C:/Butlery/butlery/assets/data/ingredient_substitutions.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Final round of checks

# 1. Check cashew products missing glutenfri tag consistently
# Cashews are naturally glutenfri. Multiple cashew products are missing it:
missing_gf_cashew = []
for i in range(101, 227):
    entry = data[i]
    name = entry['ingredientName']
    for sub in entry['substitutions']:
        sl = sub['name'].lower()
        tags = sub['dietaryTags']
        if 'cashew' in sl and 'glutenfri' not in tags:
            missing_gf_cashew.append(f"  [{i}] {name} -> {sub['name']}")

if missing_gf_cashew:
    print(f"[LOW] Cashew products missing glutenfri tag ({len(missing_gf_cashew)} entries):")
    for m in missing_gf_cashew:
        print(m)

# 2. Check [135] hasselnotskram -> mandelsm or med kakao: tagged vegetarisk not vegan
# Notes say "honung" - honung is not vegan, so vegetarisk is correct
entry = data[135]
for sub in entry['substitutions']:
    if 'mandel' in sub['name'].lower():
        if 'vegan' not in sub['dietaryTags']:
            print(f"\n[OK] [135] {sub['name']}: correctly NOT tagged vegan (uses honung)")

# 3. Missing fiskfri/skaldjursfri on non-fish/shellfish subs in fish/shellfish entries
# These tags help users with fish/shellfish allergies find safe alternatives
missing_fiskfri = []
fish_entries = [114, 130, 131, 143, 154, 200]  # fish ingredient entries
for i in fish_entries:
    entry = data[i]
    name = entry['ingredientName']
    for sub in entry['substitutions']:
        tags = sub['dietaryTags']
        sl = sub['name'].lower()
        # Non-fish substitutes should have fiskfri tag
        fish_words = ['torsk', 'abborre', 'gos', 'forell', 'roding', 'sej', 'kolja', 'piggvar', 'lax', 'gravad']
        is_fish = any(f in sl for f in fish_words)
        if not is_fish and 'fiskfri' not in tags and 'vegan' not in tags:
            # Only flag if it genuinely is fiskfri
            if 'surimi' not in sl:  # surimi is made from fish
                missing_fiskfri.append(f"  [{i}] {name} -> {sub['name']}")

if missing_fiskfri:
    print(f"\n[MEDIUM] Non-fish subs in fish entries missing fiskfri tag ({len(missing_fiskfri)}):")
    for m in missing_fiskfri:
        print(m)

# 4. Shellfish entries - non-shellfish subs missing skaldjursfri
shellfish_entries = [143, 152, 166, 206, 207, 210]
missing_skaldjursfri = []
for i in shellfish_entries:
    entry = data[i]
    name = entry['ingredientName']
    for sub in entry['substitutions']:
        tags = sub['dietaryTags']
        sl = sub['name'].lower()
        shellfish_words = ['rakor', 'hummer', 'krabba', 'mussla', 'kraftor', 'havskrafta', 'pilgrimsmussla', 'surimi']
        is_shellfish = any(f in sl for f in shellfish_words)
        if not is_shellfish and 'skaldjursfri' not in tags and 'vegan' not in tags:
            missing_skaldjursfri.append(f"  [{i}] {name} -> {sub['name']}")

if missing_skaldjursfri:
    print(f"\n[LOW] Non-shellfish subs in shellfish entries missing skaldjursfri tag ({len(missing_skaldjursfri)}):")
    for m in missing_skaldjursfri:
        print(m)

# 5. Check [222] blomkalsvingar: tagged vegan but panering (breading) typically uses eggs
# Unless vegan panering is specified
entry = data[222]
for sub in entry['substitutions']:
    if 'blomkals' in sub['name'].lower():
        tags = sub['dietaryTags']
        notes = sub['notes']
        if 'vegan' in tags and 'panera' in notes.lower():
            if 'aggfri' in tags or 'äggfri' in tags:
                print(f"\n[LOW] [222] blomkalsvingar: notes say 'Panera' (often uses egg wash) but tagged aggfri/vegan")
                print(f"  (Vegan breading is possible but should be noted)")

# 6. [175] kalkonkorv -> vaxtbaserad korv: check if glutenfri
entry = data[175]
for sub in entry['substitutions']:
    sl = sub['name'].lower()
    tags = sub['dietaryTags']
    if 'vaxtbaserad' in sl or 'växtbaserad' in sl:
        if 'glutenfri' in tags:
            print(f"\n[HIGH] [175] kalkonkorv -> {sub['name']}: vaxtbaserad korv tagged glutenfri (most contain wheat)")

# 7. Check all vaxtbaserad products for glutenfri
print("\n--- Vaxtbaserad products glutenfri check ---")
for i in range(101, 227):
    entry = data[i]
    name = entry['ingredientName']
    for sub in entry['substitutions']:
        sl = sub['name'].lower()
        tags = sub['dietaryTags']
        if 'växtbaserad' in sl and 'glutenfri' in tags:
            print(f"[HIGH] [{i}] {name} -> {sub['name']}: vaxtbaserad tagged glutenfri (most contain wheat/gluten)")

# 8. Check for missing nötfri on meat/fish products
print("\n--- Meat/fish products missing notfri ---")
count = 0
for i in range(101, 227):
    entry = data[i]
    name = entry['ingredientName']
    for sub in entry['substitutions']:
        sl = sub['name'].lower()
        tags = sub['dietaryTags']
        # Meat and fish items are naturally nut-free
        meat_fish = ['kycklingbrost', 'kalkonbrost', 'kycklingfars', 'kalkonfars',
                     'kycklingkorv', 'kalkonkorv', 'kalvkott', 'flaskfile',
                     'flankstek', 'bringa', 'kycklinglar', 'kycklinglårfil',
                     'kyckling', 'kalkon', 'kalv']
        if any(m in sl for m in meat_fish) and 'nötfri' not in tags:
            count += 1
            if count <= 10:
                print(f"  [{i}] {name} -> {sub['name']}: missing notfri tag")
if count > 10:
    print(f"  ... and {count-10} more")
print(f"  Total: {count} meat/fish subs missing notfri")

# 9. [126] and [127] buljongpulver: check glutenfri
for i in [126, 127]:
    entry = data[i]
    name = entry['ingredientName']
    for sub in entry['substitutions']:
        if 'buljongpulver' in sub['name'].lower():
            tags = sub['dietaryTags']
            if 'glutenfri' in tags:
                print(f"\n[HIGH] [{i}] {name} -> {sub['name']}: buljongpulver tagged glutenfri (many brands contain wheat)")

# 10. [150] hoisinsas -> BBQ-sas med soja: check glutenfri
entry = data[150]
for sub in entry['substitutions']:
    if 'bbq' in sub['name'].lower():
        tags = sub['dietaryTags']
        print(f"\n[150] BBQ-sas med soja tags: {tags}")
        if 'glutenfri' not in tags:
            print("[OK] Not tagged glutenfri (BBQ sauce and soja often contain gluten)")

# 11. Check [193] kokosaminos -> sojas as: correctly not tagged glutenfri
entry = data[193]
for sub in entry['substitutions']:
    if 'sojas' in sub['name'].lower() or 'sojasås' in sub['name'].lower():
        tags = sub['dietaryTags']
        print(f"\n[193] {sub['name']} tags: {tags}")
        if 'glutenfri' in tags:
            print("[CRITICAL] sojas as tagged glutenfri (regular soy sauce contains wheat)")

print("\n=== FINAL CHECKS DONE ===")
