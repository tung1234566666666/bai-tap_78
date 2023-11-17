module game_hero::hero {
    use sui::object::{Self, UID, ID};
    use sui::url::{Self, Url};
    use sui::transfer;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::sui::SUI;
    use std::string::{Self, String};
    use sui::event;
    use sui::coin::{Self, Coin};
    use std::option::{Self, Option};

    struct Hero has key, store {
        id: UID,
        hp: u64,
        mana: u64,
        level: u8,
        experience: u64,
        sword: Option<Sword>,
        game_id: ID,
    }

    struct Sword has key, store {
        id: UID,
        magic: u64,
        strength: u64,
        game_id: ID,
    }

    struct Potion has key, store {
        id: UID,
        potency: u64,
        game_id: ID,
    }

    struct Armor has key,store {
        id: UID,
        guard: u64,
        game_id: ID,
    }

    struct Monster has key, store {
        id: UID,
        hp: u64,
        strength: u64,
        game_id: ID,
    }

    struct GameInfo has key {
        id: UID,
        admin: address
    }

    struct GameAdmin has key {
        id: UID,
        monster_created: u64,
        potions_created: u64,
        game_id: ID,
    }

    struct MonsterSlainEvent has copy, drop {
        slayer_address: address,
        hero: ID,
        monster: ID,
        game_id: ID,
    }

    const EHERO_DIED: u64 = 0;
    const EDEPOSIT_TOO_LOW: u64 = 1;

    #[allow(unused_function)]
    fun init(ctx: &mut TxContext) {
        create_game(ctx);
    }

    #[only_test]
    public entry fun new(ctx: &mut TxContext) {
        create_game(ctx);
    }

    fun create_game(ctx: &mut TxContext){
        let sender = tx_context::sender(ctx);
        let id = object::new(ctx);
        let game_id = object::uid_to_inner(&id);

        transfer::freeze_object(GameInfo {
            id,
            admin: sender
        });

        transfer::transfer(
            GameAdmin {
                id: object::new(ctx),
                game_id,
                monster_created: 0,
                potions_created: 0
            }, 
            sender
        )
    }

    // --- Gameplay ---
    public entry fun attack(game: &GameInfo, hero: &mut Hero, monster: Monster, ctx: &TxContext) {
        let Monster {id: m_id, hp: m_hp, strength: monster_strength, game_id: _} = monster;

        let hero_strength = hero_strength(hero);

        let hero_hp = hero.hp;
        let _monster_hp = m_hp;

        while (_monster_hp > hero.hp) {
            if(hero_strength >= _monster_hp){
                _monster_hp = 0;
                break
            };
            _monster_hp - hero_strength;

            assert!(monster_strength > hero_hp, EHERO_DIED);
            hero_hp - monster_strength;
        };

        object::delete(m_id);

        hero.hp = hero_hp;
        level_up_hero(hero, 2);
        if (option::is_some(&hero.sword)) {
            level_up_sword(option::borrow_mut(&mut hero.sword), 2);
        };
    }

    public entry fun p2p_play(game: &GameInfo, hero1: &mut Hero, hero2: &mut Hero, ctx: &TxContext) {

    }

    public fun level_up_hero(hero: &Hero, amount: u64): u64 {
        hero.experience + amount
    }

    public fun hero_strength(hero: &Hero): u64 {
        if(hero.hp == 0) {
            return 0;
        };

        let attack = if (option::is_some(&hero.sword)) {
            sword_strength(option::borrow(&hero.sword))
        } else {
            0
        };

        hero.experience + attack

    }

    fun level_up_sword(sword: &mut Sword, amount: u64) {
        sword.strength + amount;
    }

    public fun sword_strength(sword: &Sword): u64 {
        sword.strength * sword.magic
    }

    public fun heal(hero: &mut Hero, potion: Potion) {
        let Potion { id, potency, game_id: _} = potion;
        object::delete(id);
        hero.hp = hero.hp + potency;
    }

    public fun equip_sword(hero: &mut Hero, new_sword: Sword): Option<Sword> {
        option::swap_or_fill(&mut hero.sword, new_sword)
    }

    public fun create_sword(game: &GameInfo, payment: Coin<SUI>, ctx: &mut TxContext): Sword {
        let value = coin::value(&payment);
        assert!(value >= 10, EDEPOSIT_TOO_LOW);

        transfer::public_transfer(payment, game.admin);

        Sword {
            id: object::new(ctx),
            strength: value *100,
            magic: value,
            game_id: game_id(game)
        }
    }

    public entry fun acquire_hero(
        game: &GameInfo, payment: Coin<SUI>, ctx: &mut TxContext
    ) {
        let caller = tx_context::sender(ctx);

        let new_sword = create_sword(game, payment, ctx);
        let new_hero = create_hero(game, new_sword, ctx);

        transfer::public_transfer(new_hero, caller);
    }

    public fun create_hero(game: &GameInfo, sword: Sword, ctx: &mut TxContext): Hero {
        Hero {
            id: object::new(ctx),
            hp: 100,
            experience: 0,
            level: 0,
            mana: 100,
            sword: option::some(sword),
            game_id: game_id(game)
        }
    }

    public entry fun send_potion(game: &GameInfo, payment: Coin<SUI>, ctx: &mut TxContext) {
        let potency = coin::value(&payment) * 5;
        
        let new_potion = Potion {
            id: object::new(ctx),
            potency,
            game_id: game_id(game)
        };

        transfer::public_transfer(new_potion, tx_context::sender(ctx));
        transfer::public_transfer(payment, game.admin);
    }

    public entry fun send_monster(game: &GameInfo, admin: &mut GameAdmin, hp: u64, strength: u64, player: address, ctx: &mut TxContext) {
        let new_monster = Monster {
            id: object::new(ctx),
            hp, 
            strength,
            game_id: game_id(game)
        };
        admin.monster_created = admin.monster_created + 1;

        transfer::public_transfer(new_monster, player);
    }

    public fun game_id(game: &GameInfo): ID {
        object::id(game)
    }
}
