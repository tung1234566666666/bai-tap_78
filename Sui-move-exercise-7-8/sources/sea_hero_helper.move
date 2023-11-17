module game_hero::sea_hero_helper {
    use game_hero::sea_hero::{Self, SeaMonster, VBI_TOKEN};
    use game_hero::hero::Hero;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct HelpMeSlayThisMonster has key {
        id: UID,
        monster: SeaMonster,
        monster_owner: address,
        helper_reward: u64,
    }

    public entry fun create_help(monster: SeaMonster, helper_reward: u64, helper: address, ctx: &mut TxContext,) {
        assert!(sea_hero::monster_reward(&monster) > helper_reward, 0);
        
        transfer::transfer(
            HelpMeSlayThisMonster {
                id: object::new(ctx),
                monster, 
                monster_owner: tx_context::sender(ctx),
                helper_reward
            },
            helper
        )
    }

    public entry fun attack(hero: &Hero, wrapper: HelpMeSlayThisMonster, ctx: &mut TxContext) {
        let HelpMeSlayThisMonster {
            id, 
            monster,
            monster_owner,
            helper_reward
        } = wrapper;
        object::delete(id);
        let owner_reward = sea_hero::slay(hero, monster);
        let reward = coin::take(&mut owner_reward, helper_reward, ctx);
        transfer::public_transfer(coin::from_balance(owner_reward, ctx), monster_owner);

        transfer::public_transfer(reward, tx_context::sender(ctx));
    }

    public entry fun return_to_owner(wrapper: HelpMeSlayThisMonster) {
        let HelpMeSlayThisMonster {
            id, 
            monster,
            monster_owner,
            helper_reward: _
        } = wrapper;
        object::delete(id);
        transfer::public_transfer(monster, monster_owner);
    }

    public entry fun owner_reward(wrapper: &HelpMeSlayThisMonster): u64 {
        sea_hero::monster_reward(&wrapper.monster) - wrapper.helper_reward
    }
}
