-- Keep legitimate multi-pattern Paint genetics possible, but rare in newly
-- generated Foundation horses. Existing horses retain their stored genotype.
update public.breed_foundation_genetic_population
set allele_frequency = 0.01,
    rarity = 'rare',
    notes = 'Owner-approved Paint balancing: Sabino and Splash combinations remain possible but rare',
    updated_at = now()
where breed = 'American Paint Horse'
  and locus in ('Sabino1', 'Splash1');

