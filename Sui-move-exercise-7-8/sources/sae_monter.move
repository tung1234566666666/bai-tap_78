module game_hero::sea_hero {
    use game_hero::hero::{Self, Hero};

    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance, Supply};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct SeaHeroAdmin has key {
        id: UID,
        supply: Supply<VBI_TOKEN>,
        monsters_created: u64,
        token_supply_max: u64,
        monster_max: u64
    }

    struct SeaMonster has key, store {
        id: UID,
        reward: Balance<VBI_TOKEN>
    }

    struct VBI_TOKEN has drop {}

    const EHERO_NOT_STRONG_ENOUGH: u64 = 0;
    const EINVALID_TOKEN_SUPPLY: u64 = 1;
    const EINVALID_MONSTER_SUPPLY: u64 = 2;

    fun init(ctx: &mut TxContext) {
        let game_admin = SeaHeroAdmin {
            id: object::new(ctx),
            supply: balance::create_supply<VBI_TOKEN>(VBI_TOKEN {}),
            token_supply_max: 100000,
            monster_max: 10,
            monsters_created: 0
        };

        transfer::transfer(game_admin, tx_context::sender(ctx));
    }

    #[only_test]
    public entry fun new(ctx: &mut TxContext) {
        let game_admin = SeaHeroAdmin {
            id: object::new(ctx),
            supply: balance::create_supply<VBI_TOKEN>(VBI_TOKEN {}),
            token_supply_max: 100000,
            monster_max: 10,
            monsters_created: 0
        };

        transfer::transfer(game_admin, tx_context::sender(ctx));
    }

    // --- Gameplay ---
    public entry fun attack(hero: &Hero, monster: SeaMonster, ctx: &mut TxContext){
        let reward = slay(hero, monster);
        transfer::public_transfer(coin::from_balance(reward, ctx), tx_context::sender(ctx));

    }
    public fun slay(hero: &Hero, monster: SeaMonster): Balance<VBI_TOKEN> {
        let SeaMonster {id, reward} = monster;
        object::delete(id);
        assert!(hero::hero_strength(hero) >= balance::value(&reward), EHERO_NOT_STRONG_ENOUGH);

        reward
    }

    // --- Object and coin creation ---
    public entry fun create_sea_monster(
        admin: &mut SeaHeroAdmin,
        reward_amount: u64, 
        recipient: address, 
        ctx: &mut TxContext
    ) {
        let coin_supply = balance::supply_value(&admin.supply);
        let token_supply_max = admin.token_supply_max;

        assert!(reward_amount <= token_supply_max - coin_supply, EINVALID_TOKEN_SUPPLY);
        assert!(admin.monsters_created + 1 < admin.monster_max, EINVALID_MONSTER_SUPPLY);
        let new_monster = SeaMonster {
            id: object::new(ctx),
            reward: balance::increase_supply(&mut admin.supply, reward_amount),
        };

        admin.monsters_created = admin.monsters_created + 1;
        transfer::public_transfer(new_monster, recipient);
    }

    public fun monster_reward(monster: &SeaMonster): u64 {
        balance::value(&monster.reward)
    }
}
