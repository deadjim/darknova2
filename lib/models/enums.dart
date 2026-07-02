// Pure Dart — no Flutter imports

enum TradeGood {
  water,
  furs,
  food,
  ore,
  games,
  firearms,
  medicine,
  machines,
  narcotics,
  robots,
}

enum ShipType {
  flea,
  gnat,
  firefly,
  mosquito,
  bumblebee,
  beetle,
  hornet,
  grasshopper,
  termite,
  wasp,
}

enum WeaponType {
  pulseLaser,
  beamLaser,
  militaryLaser,
}

enum ShieldType {
  energyShield,
  reflectiveShield,
}

enum GadgetType {
  extraCargoBays,
  autoRepairSystem,
  navigatingSystem,
  targetingSystem,
  cloakingDevice,
}

enum GovernmentType {
  anarchy,
  capitalistState,
  communistState,
  confederacy,
  corporateState,
  cyberneticState,
  democracy,
  dictatorship,
  fascistState,
  feudalState,
  militaryState,
  monarchy,
  pacifistState,
  socialistState,
  stateOfSatori,
  technocracy,
  theocracy,
}

enum SystemStatus {
  uneventful,
  war,
  plague,
  drought,
  boredom,
  cold,
  cropFailure,
  lackOfWorkers,
}

enum SpecialResource {
  nothingSpecial,
  mineralRich,
  mineralPoor,
  desert,
  sweetwaterOceans,
  richSoil,
  poorSoil,
  richFauna,
  lifeless,
  weirdMushrooms,
  specialHerbs,
  artisticPopulace,
  warlikePopulace,
}

enum Skill {
  pilot,
  fighter,
  trader,
  engineer,
}

enum DifficultyLevel {
  beginner,
  easy,
  normal,
  hard,
  impossible,
}

enum PoliceRecord {
  psycho,
  villain,
  criminal,
  crook,
  dubious,
  clean,
  lawful,
  trusted,
  liked,
  hero,
}

enum Reputation {
  harmless,
  mostlyHarmless,
  poor,
  average,
  aboveAverage,
  competent,
  dangerous,
  deadly,
  elite,
}

enum EncounterType {
  police,
  pirate,
  trader,
  monster,
}

extension TradeGoodName on TradeGood {
  String get displayName {
    switch (this) {
      case TradeGood.water:
        return 'Water';
      case TradeGood.furs:
        return 'Furs';
      case TradeGood.food:
        return 'Food';
      case TradeGood.ore:
        return 'Ore';
      case TradeGood.games:
        return 'Games';
      case TradeGood.firearms:
        return 'Firearms';
      case TradeGood.medicine:
        return 'Medicine';
      case TradeGood.machines:
        return 'Machines';
      case TradeGood.narcotics:
        return 'Narcotics';
      case TradeGood.robots:
        return 'Robots';
    }
  }
}

extension ShipTypeName on ShipType {
  String get displayName {
    switch (this) {
      case ShipType.flea:
        return 'Flea';
      case ShipType.gnat:
        return 'Gnat';
      case ShipType.firefly:
        return 'Firefly';
      case ShipType.mosquito:
        return 'Mosquito';
      case ShipType.bumblebee:
        return 'Bumblebee';
      case ShipType.beetle:
        return 'Beetle';
      case ShipType.hornet:
        return 'Hornet';
      case ShipType.grasshopper:
        return 'Grasshopper';
      case ShipType.termite:
        return 'Termite';
      case ShipType.wasp:
        return 'Wasp';
    }
  }
}

extension WeaponTypeName on WeaponType {
  String get displayName {
    switch (this) {
      case WeaponType.pulseLaser:
        return 'Pulse Laser';
      case WeaponType.beamLaser:
        return 'Beam Laser';
      case WeaponType.militaryLaser:
        return 'Military Laser';
    }
  }

  int get power {
    switch (this) {
      case WeaponType.pulseLaser:
        return 15;
      case WeaponType.beamLaser:
        return 25;
      case WeaponType.militaryLaser:
        return 35;
    }
  }

  int get price {
    switch (this) {
      case WeaponType.pulseLaser:
        return 2000;
      case WeaponType.beamLaser:
        return 12500;
      case WeaponType.militaryLaser:
        return 35000;
    }
  }

  int get minTechLevel {
    switch (this) {
      case WeaponType.pulseLaser:
        return 2;
      case WeaponType.beamLaser:
        return 3;
      case WeaponType.militaryLaser:
        return 5;
    }
  }
}

extension ShieldTypeName on ShieldType {
  String get displayName {
    switch (this) {
      case ShieldType.energyShield:
        return 'Energy Shield';
      case ShieldType.reflectiveShield:
        return 'Reflective Shield';
    }
  }

  int get strength {
    switch (this) {
      case ShieldType.energyShield:
        return 100;
      case ShieldType.reflectiveShield:
        return 200;
    }
  }

  int get price {
    switch (this) {
      case ShieldType.energyShield:
        return 10000;
      case ShieldType.reflectiveShield:
        return 30000;
    }
  }

  int get minTechLevel {
    switch (this) {
      case ShieldType.energyShield:
        return 2;
      case ShieldType.reflectiveShield:
        return 6;
    }
  }
}

extension GadgetTypeName on GadgetType {
  String get displayName {
    switch (this) {
      case GadgetType.extraCargoBays:
        return 'Extra Cargo Bays';
      case GadgetType.autoRepairSystem:
        return 'Auto-Repair System';
      case GadgetType.navigatingSystem:
        return 'Navigating System';
      case GadgetType.targetingSystem:
        return 'Targeting System';
      case GadgetType.cloakingDevice:
        return 'Cloaking Device';
    }
  }

  int get price {
    switch (this) {
      case GadgetType.extraCargoBays:
        return 2500;
      case GadgetType.autoRepairSystem:
        return 7500;
      case GadgetType.navigatingSystem:
        return 1500;
      case GadgetType.targetingSystem:
        return 5000;
      case GadgetType.cloakingDevice:
        return 100000;
    }
  }

  int get minTechLevel {
    switch (this) {
      case GadgetType.extraCargoBays:
        return 2;
      case GadgetType.autoRepairSystem:
        return 4;
      case GadgetType.navigatingSystem:
        return 3;
      case GadgetType.targetingSystem:
        return 3;
      case GadgetType.cloakingDevice:
        return 6;
    }
  }
}

extension GovernmentTypeName on GovernmentType {
  String get displayName {
    switch (this) {
      case GovernmentType.anarchy:
        return 'Anarchy';
      case GovernmentType.capitalistState:
        return 'Capitalist State';
      case GovernmentType.communistState:
        return 'Communist State';
      case GovernmentType.confederacy:
        return 'Confederacy';
      case GovernmentType.corporateState:
        return 'Corporate State';
      case GovernmentType.cyberneticState:
        return 'Cybernetic State';
      case GovernmentType.democracy:
        return 'Democracy';
      case GovernmentType.dictatorship:
        return 'Dictatorship';
      case GovernmentType.fascistState:
        return 'Fascist State';
      case GovernmentType.feudalState:
        return 'Feudal State';
      case GovernmentType.militaryState:
        return 'Military State';
      case GovernmentType.monarchy:
        return 'Monarchy';
      case GovernmentType.pacifistState:
        return 'Pacifist State';
      case GovernmentType.socialistState:
        return 'Socialist State';
      case GovernmentType.stateOfSatori:
        return 'State of Satori';
      case GovernmentType.technocracy:
        return 'Technocracy';
      case GovernmentType.theocracy:
        return 'Theocracy';
    }
  }
}

extension SystemStatusName on SystemStatus {
  String get displayName {
    switch (this) {
      case SystemStatus.uneventful:
        return 'Uneventful';
      case SystemStatus.war:
        return 'War';
      case SystemStatus.plague:
        return 'Plague';
      case SystemStatus.drought:
        return 'Drought';
      case SystemStatus.boredom:
        return 'Boredom';
      case SystemStatus.cold:
        return 'Cold';
      case SystemStatus.cropFailure:
        return 'Crop Failure';
      case SystemStatus.lackOfWorkers:
        return 'Lack of Workers';
    }
  }
}

extension SpecialResourceName on SpecialResource {
  String get displayName {
    switch (this) {
      case SpecialResource.nothingSpecial:
        return 'Nothing Special';
      case SpecialResource.mineralRich:
        return 'Mineral Rich';
      case SpecialResource.mineralPoor:
        return 'Mineral Poor';
      case SpecialResource.desert:
        return 'Desert';
      case SpecialResource.sweetwaterOceans:
        return 'Sweetwater Oceans';
      case SpecialResource.richSoil:
        return 'Rich Soil';
      case SpecialResource.poorSoil:
        return 'Poor Soil';
      case SpecialResource.richFauna:
        return 'Rich Fauna';
      case SpecialResource.lifeless:
        return 'Lifeless';
      case SpecialResource.weirdMushrooms:
        return 'Weird Mushrooms';
      case SpecialResource.specialHerbs:
        return 'Special Herbs';
      case SpecialResource.artisticPopulace:
        return 'Artistic Populace';
      case SpecialResource.warlikePopulace:
        return 'Warlike Populace';
    }
  }
}

extension DifficultyName on DifficultyLevel {
  String get displayName {
    switch (this) {
      case DifficultyLevel.beginner:
        return 'Beginner';
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.normal:
        return 'Normal';
      case DifficultyLevel.hard:
        return 'Hard';
      case DifficultyLevel.impossible:
        return 'Impossible';
    }
  }

  String get description {
    switch (this) {
      case DifficultyLevel.beginner:
        return 'Start with 10 skill points. Police are lenient. No starting debt.';
      case DifficultyLevel.easy:
        return 'Start with 8 skill points. A forgiving galaxy awaits.';
      case DifficultyLevel.normal:
        return 'The classic experience. 6 skill points, moderate challenge.';
      case DifficultyLevel.hard:
        return 'Start with 4 skill points. Pirates are aggressive. 1000 cr debt.';
      case DifficultyLevel.impossible:
        return 'Start with 2 skill points. Maximum hostility. 2000 cr debt.';
    }
  }

  int get startingSkillPoints {
    switch (this) {
      case DifficultyLevel.beginner:
        return 10;
      case DifficultyLevel.easy:
        return 8;
      case DifficultyLevel.normal:
        return 6;
      case DifficultyLevel.hard:
        return 4;
      case DifficultyLevel.impossible:
        return 2;
    }
  }

  int get startingDebt {
    switch (this) {
      case DifficultyLevel.beginner:
        return 0;
      case DifficultyLevel.easy:
        return 0;
      case DifficultyLevel.normal:
        return 0;
      case DifficultyLevel.hard:
        return 1000;
      case DifficultyLevel.impossible:
        return 2000;
    }
  }

  int get startingCredits {
    switch (this) {
      case DifficultyLevel.beginner:
        return 1000;
      case DifficultyLevel.easy:
        return 1000;
      case DifficultyLevel.normal:
        return 1000;
      case DifficultyLevel.hard:
        return 1000;
      case DifficultyLevel.impossible:
        return 1000;
    }
  }
}

extension PoliceRecordName on PoliceRecord {
  String get displayName {
    switch (this) {
      case PoliceRecord.psycho:
        return 'Psycho';
      case PoliceRecord.villain:
        return 'Villain';
      case PoliceRecord.criminal:
        return 'Criminal';
      case PoliceRecord.crook:
        return 'Crook';
      case PoliceRecord.dubious:
        return 'Dubious';
      case PoliceRecord.clean:
        return 'Clean';
      case PoliceRecord.lawful:
        return 'Lawful';
      case PoliceRecord.trusted:
        return 'Trusted';
      case PoliceRecord.liked:
        return 'Liked';
      case PoliceRecord.hero:
        return 'Hero';
    }
  }
}

extension ReputationName on Reputation {
  String get displayName {
    switch (this) {
      case Reputation.harmless:
        return 'Harmless';
      case Reputation.mostlyHarmless:
        return 'Mostly Harmless';
      case Reputation.poor:
        return 'Poor';
      case Reputation.average:
        return 'Average';
      case Reputation.aboveAverage:
        return 'Above Average';
      case Reputation.competent:
        return 'Competent';
      case Reputation.dangerous:
        return 'Dangerous';
      case Reputation.deadly:
        return 'Deadly';
      case Reputation.elite:
        return 'Elite';
    }
  }
}
